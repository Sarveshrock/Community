import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/news_providers.dart';
import '../widgets/news_comments_sheet.dart';

/// Shows the article the list screen already fetched (no separate re-fetch
/// — the item, including its scores/tags, is passed straight through via
/// route `extra`). "Read original source" always opens the real article;
/// this screen never reproduces its full body.
class NewsDetailScreen extends ConsumerWidget {
  const NewsDetailScreen({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSavedAsync = ref.watch(isNewsSavedProvider(item.url));
    final isSaved = isSavedAsync.valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
        actions: [
          IconButton(
            icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () async {
              final notifier = ref.read(newsControllerProvider.notifier);
              final success = isSaved
                  ? await notifier.unsave(item.url)
                  : await notifier.save(item);
              if (success && context.mounted) {
                context.showSnack(isSaved ? 'Removed from saved' : 'Saved');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.visibility_off_outlined),
            tooltip: 'Hide from feed',
            onPressed: () async {
              await ref.read(newsControllerProvider.notifier).hide(item.url);
              if (context.mounted) {
                context.showSnack('Hidden from your feed');
                Navigator.of(context).maybePop();
              }
            },
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (item.category != null || item.tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  children: [
                    if (item.category != null)
                      Chip(label: Text(item.category!)),
                    for (final tag
                        in item.tags.where((t) => t != item.category))
                      Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Text(item.title,
                  style: context.textStyles.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                [
                  if (item.source != null) item.source!,
                  if (item.publishedAt != null)
                    DateFormat.yMMMd().add_jm().format(item.publishedAt!),
                ].join(' · '),
                style: context.textStyles.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (item.description != null) ...[
                Text(item.description!),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Read original source'),
                      onPressed: () => launchUrl(Uri.parse(item.url),
                          mode: LaunchMode.externalApplication),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final count = ref
                          .watch(newsCommentsProvider(item.url))
                          .valueOrNull
                          ?.length;
                      return OutlinedButton.icon(
                        icon: const Icon(Icons.mode_comment_outlined),
                        label: Text(count == null || count == 0
                            ? 'Opinions'
                            : 'Opinions ($count)'),
                        onPressed: () =>
                            showNewsCommentsSheet(context, item.url),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
