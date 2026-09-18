import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../../home/presentation/widgets/home_style.dart';
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
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _AttachmentOption(
              icon: Icons.photo_outlined,
              label: 'Photo from gallery',
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            _AttachmentOption(
              icon: Icons.photo_camera_outlined,
              label: 'Take a photo',
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            _AttachmentOption(
              icon: Icons.attach_file,
              label: 'Document or other file',
              onTap: () => Navigator.pop(context, 'file'),
            ),
            const SizedBox(height: 8),
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
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: Column(
              children: [
                _Header(communityName: widget.communityName ?? 'Community chat'),
                Expanded(
                  child: conversationIdAsync.when(
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
                              error: (e, _) => ErrorState(
                                  message: e.toString(),
                                  onRetry: () => ref
                                      .invalidate(conversationMessagesProvider(conversationId))),
                              data: (messages) {
                                if (messages.isEmpty) {
                                  return const Center(
                                    child: Text('Say hello to the community 👋',
                                        style: TextStyle(
                                            fontSize: 14, color: HomeStyle.textSecondary)),
                                  );
                                }
                                return ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final message = messages[index];
                                    final isMine = message.senderId == myId;
                                    final showSenderName = !isMine &&
                                        (index == 0 ||
                                            messages[index - 1].senderId != message.senderId);
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
                          if (_uploading)
                            const LinearProgressIndicator(
                                minHeight: 2, color: HomeStyle.purple),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _ComposerIconButton(
                                  icon: _showEmojiPicker
                                      ? Icons.keyboard_outlined
                                      : Icons.emoji_emotions_outlined,
                                  onTap: _toggleEmojiPicker,
                                ),
                                const SizedBox(width: 4),
                                _ComposerIconButton(
                                  icon: Icons.attach_file,
                                  onTap: _uploading
                                      ? null
                                      : () => _openAttachmentSheet(conversationId),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Container(
                                    constraints: const BoxConstraints(minHeight: 44),
                                    decoration: BoxDecoration(
                                      color: HomeStyle.cardBase,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.08)),
                                    ),
                                    child: TextField(
                                      controller: _textController,
                                      focusNode: _textFieldFocusNode,
                                      minLines: 1,
                                      maxLines: 4,
                                      textCapitalization: TextCapitalization.sentences,
                                      style: const TextStyle(
                                          color: HomeStyle.textPrimary, fontSize: 14),
                                      decoration: const InputDecoration(
                                        hintText: 'Message the community...',
                                        hintStyle: TextStyle(color: HomeStyle.textSecondary),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                      ),
                                      onTap: () {
                                        if (_showEmojiPicker) {
                                          setState(() => _showEmojiPicker = false);
                                        }
                                      },
                                      onSubmitted: (_) => _send(conversationId),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _SendButton(onTap: () => _send(conversationId)),
                              ],
                            ),
                          ),
                          Offstage(
                            offstage: !_showEmojiPicker,
                            child: SizedBox(
                              height: 280,
                              child: EmojiPicker(
                                onEmojiSelected: _onEmojiSelected,
                                config: const Config(
                                  height: 280,
                                  emojiViewConfig: EmojiViewConfig(
                                    emojiSizeMax: 28,
                                    backgroundColor: HomeStyle.cardBase,
                                  ),
                                  categoryViewConfig: CategoryViewConfig(
                                    backgroundColor: HomeStyle.cardBase,
                                    indicatorColor: HomeStyle.purple,
                                    iconColorSelected: HomeStyle.purple,
                                    iconColor: HomeStyle.textSecondary,
                                    backspaceColor: HomeStyle.purple,
                                    dividerColor: Colors.transparent,
                                  ),
                                  bottomActionBarConfig: BottomActionBarConfig(
                                    backgroundColor: HomeStyle.cardBase,
                                    buttonColor: HomeStyle.purple,
                                    buttonIconColor: Colors.white,
                                  ),
                                  searchViewConfig: SearchViewConfig(
                                    backgroundColor: HomeStyle.cardBase,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.communityName});

  final String communityName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          _IconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: () => context.pop()),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: HomeStyle.brandGradient,
            ),
            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              communityName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: HomeStyle.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: HomeStyle.cardBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 20, color: HomeStyle.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeStyle.cardBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon,
              size: 20,
              color: onTap == null
                  ? HomeStyle.textSecondary.withValues(alpha: 0.4)
                  : HomeStyle.textSecondary),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: HomeStyle.brandGradient,
            boxShadow: HomeStyle.glow(HomeStyle.purple, opacity: 0.35, blur: 12),
          ),
          child: const Icon(Icons.send_rounded, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: HomeStyle.purple),
      title: Text(label, style: const TextStyle(color: HomeStyle.textPrimary)),
      onTap: onTap,
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
    final textColor = isMine ? Colors.white : HomeStyle.textPrimary;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 18),
    );

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      decoration: BoxDecoration(
        gradient: isMine ? HomeStyle.brandGradient : null,
        color: isMine ? null : HomeStyle.cardBase,
        border: isMine ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: borderRadius,
      ),
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
                    backgroundColor: HomeStyle.cardBase,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => SafeArea(
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline, color: HomeStyle.pink),
                        title: const Text('Delete message',
                            style: TextStyle(color: HomeStyle.textPrimary)),
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
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: HomeStyle.textSecondary),
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
      loading: () => const SizedBox(
          width: 160,
          height: 160,
          child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: HomeStyle.purple))),
      error: (_, __) => const SizedBox(
          width: 160,
          height: 100,
          child: Center(
              child: Icon(Icons.broken_image_outlined, color: HomeStyle.textSecondary))),
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
                width: 220,
                height: 220,
                child: Center(
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: HomeStyle.purple))),
            errorWidget: (_, __, ___) => const SizedBox(
                width: 220,
                height: 120,
                child: Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: HomeStyle.textSecondary))),
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
