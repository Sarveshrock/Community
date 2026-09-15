import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../providers/news_providers.dart';

/// Opinions (and replies to opinions) on one news article, in a draggable
/// sheet — mirrors `PostCommentsSheet`. Replies are flattened one level
/// deep and always show who they're addressed to via a structured "Replying
/// to @Name" tag (from [NewsComment.mentionedName]), rather than relying on
/// parsing free-text for an "@" the user could edit away.
Future<void> showNewsCommentsSheet(BuildContext context, String articleUrl) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => NewsCommentsSheet(articleUrl: articleUrl),
  );
}

class _ReplyTarget {
  const _ReplyTarget(
      {required this.topLevelCommentId,
      required this.profileId,
      required this.name});
  final String topLevelCommentId;
  final String profileId;
  final String name;
}

class NewsCommentsSheet extends ConsumerStatefulWidget {
  const NewsCommentsSheet({super.key, required this.articleUrl});
  final String articleUrl;

  @override
  ConsumerState<NewsCommentsSheet> createState() => _NewsCommentsSheetState();
}

class _NewsCommentsSheetState extends ConsumerState<NewsCommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  _ReplyTarget? _replyingTo;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startReply(NewsComment target) {
    final myId = ref.read(authStateProvider).valueOrNull?.id;
    final name =
        getDisplayName(ref, profileId: target.authorId, mainName: target.authorName);
    setState(() {
      _replyingTo = _ReplyTarget(
        topLevelCommentId: target.parentCommentId ?? target.id,
        profileId: target.authorId,
        name: name,
      );
      if (target.authorId != myId) {
        _controller.text = '@$name ';
        _controller.selection =
            TextSelection.collapsed(offset: _controller.text.length);
      }
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _controller.clear();
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final replyingTo = _replyingTo;
    _controller.clear();
    setState(() => _replyingTo = null);
    final ok = await ref.read(newsControllerProvider.notifier).addComment(
          widget.articleUrl,
          text,
          parentCommentId: replyingTo?.topLevelCommentId,
          mentionedProfileId: replyingTo?.profileId,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok == null) context.showSnack('Could not post your opinion', isError: true);
  }

  Future<void> _delete(NewsComment comment) async {
    final ok = await ref
        .read(newsControllerProvider.notifier)
        .deleteComment(comment.id, widget.articleUrl);
    if (!mounted) return;
    if (!ok) context.showSnack('Could not delete comment', isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final commentsAsync = ref.watch(newsCommentsProvider(widget.articleUrl));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Text('Opinions', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: commentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (comments) {
                if (comments.isEmpty) {
                  return const EmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No opinions yet',
                      message: 'Be the first to share what you think.');
                }
                final topLevel = comments.where((c) => !c.isReply).toList();
                final repliesByParent = <String, List<NewsComment>>{};
                for (final c in comments.where((c) => c.isReply)) {
                  repliesByParent.putIfAbsent(c.parentCommentId!, () => []).add(c);
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: topLevel.length,
                  itemBuilder: (context, i) {
                    final comment = topLevel[i];
                    final replies = repliesByParent[comment.id] ?? const [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CommentTile(
                            comment: comment,
                            isOwn: comment.authorId == myId,
                            onReply: () => _startReply(comment),
                            onDelete: () => _delete(comment),
                          ),
                          for (final reply in replies)
                            Padding(
                              padding: const EdgeInsets.only(left: 36, top: 10),
                              child: _CommentTile(
                                comment: reply,
                                isOwn: reply.authorId == myId,
                                onReply: () => _startReply(reply),
                                onDelete: () => _delete(reply),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_replyingTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Replying to ${_replyingTo!.name}',
                              style: context.textStyles.bodySmall
                                  ?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: _cancelReply,
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: _replyingTo != null
                                ? 'Write a reply...'
                                : 'Share your opinion...',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _sending
                          ? const SizedBox(
                              width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton.filled(icon: const Icon(Icons.send_rounded), onPressed: _send),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({
    required this.comment,
    required this.isOwn,
    required this.onReply,
    required this.onDelete,
  });

  final NewsComment comment;
  final bool isOwn;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(avatarUrl: comment.authorAvatarUrl, name: comment.authorName ?? '?', radius: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      getDisplayName(ref, profileId: comment.authorId, mainName: comment.authorName),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    timeago.format(comment.createdAt, locale: 'en_short'),
                    style: context.textStyles.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  if (isOwn)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                    ),
                ],
              ),
              if (comment.isReply && comment.mentionedName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'Replying to ${comment.mentionedName}',
                    style: context.textStyles.bodySmall
                        ?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              Text(comment.content),
              const SizedBox(height: 2),
              InkWell(
                onTap: onReply,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Reply',
                    style: context.textStyles.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
