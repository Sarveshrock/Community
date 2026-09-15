import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../providers/news_providers.dart';

/// Curated tech intelligence feed — every item here already passed the
/// get-news pipeline's relevance filter server-side (spec: "not a generic
/// news feed"). Filtering/pagination both stay server-side; this screen
/// only asks for the next slice.
class NewsListScreen extends ConsumerWidget {
  const NewsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(newsFeedControllerProvider);
    final selectedCategory = ref.watch(newsCategoryFilterProvider);
    final trendingOnly = ref.watch(newsTrendingOnlyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tech Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Saved',
            onPressed: () => context.push(RoutePaths.newsSaved),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Latest',
                      selected: selectedCategory == null && !trendingOnly,
                      onTap: () {
                        ref.read(newsCategoryFilterProvider.notifier).state =
                            null;
                        ref.read(newsTrendingOnlyProvider.notifier).state =
                            false;
                      },
                    ),
                    _FilterChip(
                      label: 'Trending',
                      icon: Icons.trending_up,
                      selected: trendingOnly,
                      onTap: () {
                        ref.read(newsCategoryFilterProvider.notifier).state =
                            null;
                        ref.read(newsTrendingOnlyProvider.notifier).state =
                            true;
                      },
                    ),
                    for (final category in kNewsCategories)
                      _FilterChip(
                        label: category,
                        selected: !trendingOnly && selectedCategory == category,
                        onTap: () {
                          ref.read(newsCategoryFilterProvider.notifier).state =
                              category;
                          ref.read(newsTrendingOnlyProvider.notifier).state =
                              false;
                        },
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(newsFeedControllerProvider),
                child: feedAsync.when(
                  loading: () => const SkeletonList(),
                  error: (e, _) => ErrorState(
                    message: 'Couldn\'t load news right now.',
                    onRetry: () => ref.invalidate(newsFeedControllerProvider),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyState(
                        icon: Icons.newspaper_outlined,
                        title: 'No news right now',
                        message:
                            'Try a different category or check back after the next refresh.',
                      );
                    }
                    final hasMore =
                        ref.read(newsFeedControllerProvider.notifier).hasMore;
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length + (hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i >= items.length) {
                          return _LoadMoreButton(
                              onTap: () => ref
                                  .read(newsFeedControllerProvider.notifier)
                                  .loadMore());
                        }
                        return _NewsCard(item: items[i]);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends ConsumerWidget {
  const _NewsCard({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          ref.read(newsControllerProvider.notifier).openArticle(item.url);
          context.push(RoutePaths.newsDetail, extra: item);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  if (item.source != null)
                    Flexible(
                      child: Text(
                        item.source!,
                        style: context.textStyles.bodySmall?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (item.isTrending) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.trending_up,
                        size: 14, color: context.colors.error),
                  ],
                  const Spacer(),
                  if (item.publishedAt != null)
                    Text(timeago.format(item.publishedAt!, locale: 'en_short'),
                        style: context.textStyles.bodySmall),
                ],
              ),
              const SizedBox(height: 6),
              Text(item.title,
                  style: context.textStyles.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (item.description != null) ...[
                const SizedBox(height: 6),
                Text(item.description!,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final tag in item.tags.take(3))
                      Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        avatar: icon != null ? Icon(icon, size: 16) : null,
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
          child:
              OutlinedButton(onPressed: onTap, child: const Text('Load more'))),
    );
  }
}
