import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/post_providers.dart';
import '../widgets/post_card.dart';

/// The dedicated Posts section (reached from Discover) — a tech/developer
/// feed, not a generic social feed: category chips keep it scoped, and
/// browsing here is entirely separate from creating (Create tab / Home /
/// Profile all push the same composer instead).
class PostsFeedScreen extends ConsumerStatefulWidget {
  const PostsFeedScreen({super.key});

  @override
  ConsumerState<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends ConsumerState<PostsFeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(postsFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(postsFeedProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      floatingActionButton: _CreatePostButton(
        onTap: () => context.push(RoutePaths.newPost),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        _IconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          onTap: () => context.pop(),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Posts',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: feedAsync.when(
                      loading: () => const SkeletonList(),
                      error: (e, _) => ErrorState(
                          message: e.toString(),
                          onRetry: () => ref.invalidate(postsFeedProvider)),
                      data: (state) {
                        return RefreshIndicator(
                          backgroundColor: HomeStyle.cardBase,
                          color: HomeStyle.purple,
                          onRefresh: () =>
                              ref.read(postsFeedProvider.notifier).refresh(),
                          child: CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              SliverToBoxAdapter(
                                  child: _CategoryChips(
                                      selected: state.category)),
                              if (state.posts.isEmpty)
                                const SliverFillRemaining(
                                  child: EmptyState(
                                    icon: Icons.forum_outlined,
                                    title: 'No posts yet',
                                    message:
                                        'Be the first to share something about tech or your latest project.',
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 90),
                                  sliver: SliverList.separated(
                                    itemCount: state.posts.length +
                                        (state.hasMore ? 1 : 0),
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      if (i >= state.posts.length) {
                                        return const Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 16),
                                          child: Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: HomeStyle.purple)),
                                        );
                                      }
                                      return PostCard(post: state.posts[i]);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
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
              width: 44,
              height: 44,
              child: Icon(icon, size: 21, color: HomeStyle.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatePostButton extends StatelessWidget {
  const _CreatePostButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: HomeStyle.brandGradient,
            borderRadius: BorderRadius.circular(100),
            boxShadow: HomeStyle.glow(HomeStyle.purple, opacity: 0.4, blur: 16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 6),
              Text('Post',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _Chip(
            label: 'All',
            selected: selected == null,
            onTap: () => ref.read(postsFeedProvider.notifier).setCategory(null),
          ),
          for (final category in kPostCategories)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Chip(
                label: category,
                selected: selected == category,
                onTap: () =>
                    ref.read(postsFeedProvider.notifier).setCategory(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? HomeStyle.brandGradient : null,
            color: selected ? null : HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : HomeStyle.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
