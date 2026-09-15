import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
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
      appBar: AppBar(title: const Text('Posts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.newPost),
        icon: const Icon(Icons.add),
        label: const Text('Post'),
      ),
      body: ResponsiveCenter(
        child: feedAsync.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ErrorState(
              message: e.toString(),
              onRetry: () => ref.invalidate(postsFeedProvider)),
          data: (state) {
            return RefreshIndicator(
              onRefresh: () => ref.read(postsFeedProvider.notifier).refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                      child: _CategoryChips(selected: state.category)),
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList.separated(
                        itemCount: state.posts.length + (state.hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          if (i >= state.posts.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
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
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) =>
                  ref.read(postsFeedProvider.notifier).setCategory(null),
            ),
          ),
          for (final category in kPostCategories)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(category),
                selected: selected == category,
                onSelected: (_) =>
                    ref.read(postsFeedProvider.notifier).setCategory(category),
              ),
            ),
        ],
      ),
    );
  }
}
