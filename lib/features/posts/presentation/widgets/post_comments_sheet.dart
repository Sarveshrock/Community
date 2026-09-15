import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../providers/post_providers.dart';

/// Comments for one post, in a draggable sheet — opened from `PostCard`'s
/// comment button. Reuses `getDisplayName()` for every commenter's name,
/// same as everywhere else a person's name renders in the app.
Future<void> showPostCommentsSheet(BuildContext context, String postId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PostCommentsSheet(postId: postId),
  );
}

class PostCommentsSheet extends ConsumerStatefulWidget {
  const PostCommentsSheet({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<PostCommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    final ok = await ref.read(postControllerProvider.notifier).addComment(widget.postId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok == null) context.showSnack('Could not post comment', isError: true);
  }

  Future<void> _delete(String commentId) async {
    final ok = await ref.read(postControllerProvider.notifier).deleteComment(commentId, widget.postId);
    if (!mounted) return;
    if (!ok) context.showSnack('Could not delete comment', isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Text('Comments', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: commentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (comments) {
                if (comments.isEmpty) {
                  return const EmptyState(icon: Icons.mode_comment_outlined, title: 'No comments yet');
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, i) {
                    final c = comments[i];
                    final isOwn = c.authorId == myId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserAvatar(avatarUrl: c.authorAvatarUrl, name: c.authorName ?? '?', radius: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        getDisplayName(ref, profileId: c.authorId, mainName: c.authorName),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text(
                                      timeago.format(c.createdAt, locale: 'en_short'),
                                      style: context.textStyles.bodySmall
                                          ?.copyWith(color: context.colors.onSurfaceVariant),
                                    ),
                                    if (isOwn)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _delete(c.id),
                                      ),
                                  ],
                                ),
                                Text(c.content),
                              ],
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Add a comment...'),
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
            ),
          ),
        ],
      ),
    );
  }
}
