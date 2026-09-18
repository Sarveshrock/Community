import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../moderation/presentation/widgets/report_action_button.dart';
import '../providers/post_providers.dart';
import 'post_comments_sheet.dart';

/// The single reusable feed-item widget — used identically in the
/// dedicated Posts feed, the Home page preview, and a profile's Posts
/// section (spec: "do not create three separate implementations").
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, this.openOnTap = true});

  final Post post;

  /// False on the detail screen itself, so tapping the card there doesn't
  /// try to push another copy of the same route.
  final bool openOnTap;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  Post get post => widget.post;

  late int _likeCount = post.likeCount;

  /// Set the instant a like/unlike is tapped, so the heart flips
  /// immediately instead of waiting on a round-trip — `posts.like_count`
  /// itself is kept correct server-side by a DB trigger regardless, this
  /// is purely a local optimistic mirror of it.
  bool? _likedOverride;
  bool _liking = false;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete post?',
      message:
          'Are you sure you want to delete this post? This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref
        .read(postControllerProvider.notifier)
        .deletePost(post.id, authorId: post.authorId);
    if (!context.mounted) return;
    context.showSnack(ok ? 'Post deleted' : 'Could not delete post',
        isError: !ok);
  }

  Future<void> _toggleLike(bool currentlyLiked) async {
    if (_liking) return;
    setState(() {
      _liking = true;
      _likedOverride = !currentlyLiked;
      _likeCount += currentlyLiked ? -1 : 1;
    });
    final ok = await ref
        .read(postControllerProvider.notifier)
        .setLiked(post.id, liked: !currentlyLiked);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _likedOverride = currentlyLiked;
        _likeCount += currentlyLiked ? 1 : -1;
      });
      context.showSnack('Could not update like', isError: true);
    }
    setState(() => _liking = false);
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final isOwner = post.authorId == myId;
    final isLiked = _likedOverride ??
        ref.watch(isPostLikedByMeProvider(post.id)).valueOrNull ??
        false;

    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    context.push(RoutePaths.personDetailOf(post.authorId)),
                child: UserAvatar(
                  avatarUrl: post.authorAvatarUrl,
                  name: post.authorName ?? '?',
                  radius: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getDisplayName(ref,
                          profileId: post.authorId, mainName: post.authorName),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: HomeStyle.textPrimary,
                      ),
                    ),
                    Text(
                      [
                        timeago.format(post.createdAt, locale: 'en_short'),
                        if (post.category != null) post.category!,
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: HomeStyle.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') _delete(context);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                )
              else
                ReportActionButton(
                    targetType: ReportTargetType.post, targetId: post.id),
            ],
          ),
          if (post.content != null && post.content!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(post.content!,
                style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: HomeStyle.textPrimary)),
          ],
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PostMediaCarousel(media: post.media),
          ],
          if (post.links.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final link in post.links)
              Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _LinkCard(link: link)),
          ],
          if (post.mentions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in post.mentions)
                  Material(
                    color: HomeStyle.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: () => context
                          .push(RoutePaths.personDetailOf(m.profileId)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alternate_email,
                                size: 13, color: HomeStyle.purple),
                            const SizedBox(width: 4),
                            Text(
                              getDisplayName(ref,
                                  profileId: m.profileId,
                                  mainName: m.fullName),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: HomeStyle.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: HomeStyle.textSecondary),
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: isLiked ? HomeStyle.pink : HomeStyle.textSecondary,
                ),
                label: Text('$_likeCount',
                    style: TextStyle(
                        color:
                            isLiked ? HomeStyle.pink : HomeStyle.textSecondary,
                        fontWeight: FontWeight.w600)),
                onPressed: myId == null || _liking ? null : () => _toggleLike(isLiked),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: HomeStyle.textSecondary),
                icon: const Icon(Icons.mode_comment_outlined,
                    size: 18, color: HomeStyle.textSecondary),
                label: Text('${post.commentCount}',
                    style: const TextStyle(
                        color: HomeStyle.textSecondary,
                        fontWeight: FontWeight.w600)),
                onPressed: () => showPostCommentsSheet(context, post.id),
              ),
            ],
          ),
        ],
      ),
    );

    return Material(
      color: HomeStyle.cardBase,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: widget.openOnTap
            ? InkWell(
                onTap: () => context.push(RoutePaths.postDetailOf(post.id)),
                child: content)
            : content,
      ),
    );
  }
}

class _PostMediaCarousel extends StatefulWidget {
  const _PostMediaCarousel({required this.media});
  final List<PostMedia> media;

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final repo = ref.watch(postRepositoryProvider);
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 240,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.media.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final m = widget.media[i];
                  final url = repo.getMediaPublicUrl(m.storagePath);
                  return m.type == PostMediaType.video
                      ? _PostVideoPlayer(url: url)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined)),
                        );
                },
              ),
            ),
          ),
          if (widget.media.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.media.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? HomeStyle.purple
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
    });
  }
}

class _PostVideoPlayer extends StatefulWidget {
  const _PostVideoPlayer({required this.url});
  final String url;

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return GestureDetector(
      onTap: () => setState(() {
        _controller.value.isPlaying ? _controller.pause() : _controller.play();
      }),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio == 0
                    ? 16 / 9
                    : _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, _) {
                if (value.isPlaying) return const SizedBox.shrink();
                return Container(
                  decoration: const BoxDecoration(
                      color: Colors.black45, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(14),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 36),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.link});
  final PostLink link;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () =>
          launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HomeStyle.cardBase,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.link, color: HomeStyle.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.domain ?? link.url,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: HomeStyle.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    link.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: HomeStyle.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new,
                size: 16, color: HomeStyle.textSecondary),
          ],
        ),
      ),
    );
  }
}
