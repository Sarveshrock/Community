import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../../../messaging/domain/entities/message.dart';
import '../../../messaging/presentation/providers/message_providers.dart';
import '../providers/community_providers.dart';

const _maxAttachmentBytes = 25 * 1024 * 1024; // 25 MB
const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'};

/// A community's private group chat — mirrors `TeamChatScreen` exactly
/// (same messaging providers/widgets/attachment flow, spec: "reuse existing
/// chat infrastructure, do not create a completely separate messaging
/// system"). Access is enforced server-side (RLS on `messages`/
/// `conversations` via `is_conversation_member`), so a null conversation id
/// here means either the chat hasn't been created yet or the viewer truly
/// isn't a member.
class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({super.key, required this.communityId, this.communityName});

  final String communityId;
  final String? communityName;

  @override
  ConsumerState<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _textFieldFocusNode = FocusNode();
  int _lastMessageCount = 0;
  bool _initialScrollDone = false;
  bool _showEmojiPicker = false;
  bool _uploading = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 120;
  }

  void _handleNewMessages(List<Message> messages, String? myId) {
    if (!_initialScrollDone) {
      _initialScrollDone = true;
      _lastMessageCount = messages.length;
      _scrollToBottom(animate: false);
      return;
    }
    final grew = messages.length > _lastMessageCount;
    _lastMessageCount = messages.length;
    if (!grew) return;

    final last = messages.last;
    final isMine = last.senderId == myId;
    if (isMine || _isNearBottom) {
      _scrollToBottom(animate: true);
    }
  }

  Future<void> _send(String conversationId) async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    await ref.read(messageControllerProvider.notifier).sendText(conversationId, text);
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      return;
    }
    _textFieldFocusNode.unfocus();
    setState(() => _showEmojiPicker = true);
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    _textController.text += emoji.emoji;
    _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
  }

  Future<void> _openAttachmentSheet(String conversationId) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Document or other file'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case 'gallery':
        await _pickAndSendImage(conversationId, ImageSource.gallery);
      case 'camera':
        await _pickAndSendImage(conversationId, ImageSource.camera);
      case 'file':
        await _pickAndSendFile(conversationId);
    }
  }

  Future<void> _pickAndSendImage(String conversationId, ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _uploadAndSend(conversationId, bytes: bytes, fileName: picked.name, type: MessageType.image);
  }

  Future<void> _pickAndSendFile(String conversationId) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final extension = (file.extension ?? '').toLowerCase();
    final type = _imageExtensions.contains(extension) ? MessageType.image : MessageType.file;
    await _uploadAndSend(conversationId, bytes: bytes, fileName: file.name, type: type);
  }

  Future<void> _uploadAndSend(
    String conversationId, {
    required Uint8List bytes,
    required String fileName,
    required MessageType type,
  }) async {
    if (bytes.length > _maxAttachmentBytes) {
      if (mounted) context.showSnack('That file is too large (25 MB max)', isError: true);
      return;
    }
    setState(() => _uploading = true);
    final ok = await ref.read(messageControllerProvider.notifier).sendAttachment(
          conversationId,
          bytes: bytes,
          fileName: fileName,
          type: type,
        );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (!ok) context.showSnack('Could not send attachment', isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final conversationIdAsync = ref.watch(communityConversationIdProvider(widget.communityId));
    final membersAsync = ref.watch(communityMembersProvider(widget.communityId));
    final membersById = <String, CommunityMember>{
      for (final m in membersAsync.valueOrNull ?? const <CommunityMember>[]) m.profileId: m,
    };

    return Scaffold(
      appBar: AppBar(title: Text(widget.communityName ?? 'Community chat')),
      body: conversationIdAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(communityConversationIdProvider(widget.communityId)),
        ),
        data: (conversationId) {
          if (conversationId == null) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'No access to this chat',
              message: 'Only current members can view this conversation.',
            );
          }
          final messagesAsync = ref.watch(conversationMessagesProvider(conversationId));
          messagesAsync.whenData((messages) => _handleNewMessages(messages, myId));

          return Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  loading: () => const LoadingState(),
                  error: (e, _) =>
                      ErrorState(message: e.toString(), onRetry: () => ref.invalidate(conversationMessagesProvider(conversationId))),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return Center(
                        child: Text('Say hello to the community 👋',
                            style: context.textStyles.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message.senderId == myId;
                        final showSenderName =
                            !isMine && (index == 0 || messages[index - 1].senderId != message.senderId);
                        return _CommunityMessageBubble(
                          message: message,
                          isMine: isMine,
                          sender: showSenderName ? membersById[message.senderId] : null,
                        );
                      },
                    );
                  },
                ),
              ),
              if (_uploading) const LinearProgressIndicator(minHeight: 2),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_showEmojiPicker ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined),
                        onPressed: _toggleEmojiPicker,
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: _uploading ? null : () => _openAttachmentSheet(conversationId),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _textFieldFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(hintText: 'Message the community...'),
                          onTap: () {
                            if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                          },
                          onSubmitted: (_) => _send(conversationId),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(icon: const Icon(Icons.send_rounded), onPressed: () => _send(conversationId)),
                    ],
                  ),
                ),
              ),
              Offstage(
                offstage: !_showEmojiPicker,
                child: SizedBox(
                  height: 280,
                  child: EmojiPicker(
                    onEmojiSelected: _onEmojiSelected,
                    config: const Config(height: 280, emojiViewConfig: EmojiViewConfig(emojiSizeMax: 28)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CommunityMessageBubble extends ConsumerWidget {
  const _CommunityMessageBubble({required this.message, required this.isMine, this.sender});

  final Message message;
  final bool isMine;
  final CommunityMember? sender;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bubbleColor = isMine ? context.colors.primary : context.colors.surfaceContainerHighest;
    final textColor = isMine ? context.colors.onPrimary : context.colors.onSurface;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 18),
    );

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      decoration: BoxDecoration(color: bubbleColor, borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: message.type == MessageType.image && !message.isDeleted
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContent(context, textColor),
            const SizedBox(height: 4),
            Padding(
              padding: message.type == MessageType.image ? const EdgeInsets.symmetric(horizontal: 6) : EdgeInsets.zero,
              child: Text(DateFormat.Hm().format(message.createdAt),
                  style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7))),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: isMine
              ? () => showModalBottomSheet(
                    context: context,
                    builder: (context) => SafeArea(
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: const Text('Delete message'),
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(messageControllerProvider.notifier).deleteMessage(message.id);
                        },
                      ),
                    ),
                  )
              : null,
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (sender != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2, top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserAvatar(avatarUrl: sender!.avatarUrl, name: sender!.displayName, radius: 9),
                      const SizedBox(width: 6),
                      Text(
                        getDisplayName(ref, profileId: sender!.profileId, mainName: sender!.fullName),
                        style: context.textStyles.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              bubble,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    if (message.isDeleted) {
      return Text('Message deleted',
          style: TextStyle(color: textColor.withValues(alpha: 0.6), fontStyle: FontStyle.italic));
    }
    switch (message.type) {
      case MessageType.image:
        return _ImageAttachment(message: message);
      case MessageType.file:
        return _FileAttachment(message: message, textColor: textColor);
      case MessageType.text:
      case MessageType.system:
        return Text(message.content ?? '', style: TextStyle(color: textColor));
    }
  }
}

class _ImageAttachment extends ConsumerWidget {
  const _ImageAttachment({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(attachmentSignedUrlProvider(message.attachmentUrl!));
    return urlAsync.when(
      loading: () => const SizedBox(width: 160, height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox(width: 160, height: 100, child: Center(child: Icon(Icons.broken_image_outlined))),
      data: (url) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullScreenImage(url: url))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: 220,
            height: 220,
            placeholder: (_, __) => const SizedBox(
                width: 220, height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorWidget: (_, __, ___) =>
                const SizedBox(width: 220, height: 120, child: Center(child: Icon(Icons.broken_image_outlined))),
          ),
        ),
      ),
    );
  }
}

class _FileAttachment extends ConsumerWidget {
  const _FileAttachment({required this.message, required this.textColor});
  final Message message;
  final Color textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(attachmentSignedUrlProvider(message.attachmentUrl!));
    final fileName = message.content ?? 'Attachment';

    return InkWell(
      onTap: () async {
        final url = urlAsync.valueOrNull;
        if (url == null) return;
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(fileName), color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(fileName,
                style: TextStyle(color: textColor, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis),
          ),
          if (urlAsync.isLoading) ...[
            const SizedBox(width: 8),
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: textColor)),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'doc' || 'docx' => Icons.description_outlined,
      'ppt' || 'pptx' => Icons.slideshow_outlined,
      'xls' || 'xlsx' || 'csv' => Icons.table_chart_outlined,
      'zip' || 'rar' || '7z' => Icons.folder_zip_outlined,
      'mp3' || 'wav' || 'm4a' => Icons.audiotrack_outlined,
      'mp4' || 'mov' || 'avi' => Icons.videocam_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url))),
    );
  }
}
