import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart';
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
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(onSaved: () => context.push(RoutePaths.newsSaved)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
                      backgroundColor: HomeStyle.cardBase,
                      color: HomeStyle.purple,
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
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSaved});

  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _IconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: () => context.pop()),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Tech Intelligence',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          _IconButton(
              icon: Icons.bookmark_outline,
              tooltip: 'Saved',
              onTap: onSaved),
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

class _NewsCard extends ConsumerWidget {
  const _NewsCard({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: HomeStyle.cardBase,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(newsControllerProvider.notifier).openArticle(item.url);
          context.push(RoutePaths.newsDetail, extra: item);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          padding: const EdgeInsets.all(14),
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
                        style: const TextStyle(
                            fontSize: 12,
                            color: HomeStyle.blue,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (item.isTrending) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.trending_up,
                        size: 14, color: HomeStyle.pink),
                  ],
                  const Spacer(),
                  if (item.publishedAt != null)
                    Text(timeago.format(item.publishedAt!, locale: 'en_short'),
                        style: const TextStyle(
                            fontSize: 11, color: HomeStyle.textSecondary)),
                ],
              ),
              const SizedBox(height: 6),
              Text(item.title,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: HomeStyle.textPrimary)),
              if (item.description != null) ...[
                const SizedBox(height: 6),
                Text(item.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: HomeStyle.textSecondary)),
              ],
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in item.tags.take(3))
                      HomeChip(tag, accent: HomeStyle.purple),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: selected ? HomeStyle.brandGradient : null,
              color: selected ? null : HomeStyle.cardBase,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 15,
                      color: selected ? Colors.white : HomeStyle.textSecondary),
                  const SizedBox(width: 5),
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : HomeStyle.textSecondary)),
              ],
            ),
          ),
        ),
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
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: HomeStyle.textPrimary,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: const Text('Load more'),
        ),
      ),
    );
  }
}
