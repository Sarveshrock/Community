import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../home/presentation/widgets/home_style.dart';
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
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(
                    isSaved: isSaved,
                    onToggleSave: () async {
                      final notifier = ref.read(newsControllerProvider.notifier);
                      final success = isSaved
                          ? await notifier.unsave(item.url)
                          : await notifier.save(item);
                      if (success && context.mounted) {
                        context.showSnack(
                            isSaved ? 'Removed from saved' : 'Saved');
                      }
                    },
                    onHide: () async {
                      await ref.read(newsControllerProvider.notifier).hide(item.url);
                      if (context.mounted) {
                        context.showSnack('Hidden from your feed');
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
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
                                errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (item.category != null ||
                              item.tags.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (item.category != null)
                                  HomeChip(item.category!,
                                      accent: HomeStyle.purple),
                                for (final tag in item.tags
                                    .where((t) => t != item.category))
                                  HomeChip(tag, accent: HomeStyle.blue),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(item.title,
                              style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: HomeStyle.textPrimary,
                                  height: 1.3)),
                          const SizedBox(height: 8),
                          Text(
                            [
                              if (item.source != null) item.source!,
                              if (item.publishedAt != null)
                                DateFormat.yMMMd().add_jm().format(item.publishedAt!),
                            ].join(' · '),
                            style: const TextStyle(
                                fontSize: 12.5, color: HomeStyle.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          if (item.description != null) ...[
                            Text(item.description!,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.5,
                                    color: HomeStyle.textPrimary)),
                            const SizedBox(height: 18),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: _OutlineButton(
                                  icon: Icons.open_in_new,
                                  label: 'Read original source',
                                  onTap: () => launchUrl(Uri.parse(item.url),
                                      mode: LaunchMode.externalApplication),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Consumer(
                                builder: (context, ref, _) {
                                  final count = ref
                                      .watch(newsCommentsProvider(item.url))
                                      .valueOrNull
                                      ?.length;
                                  return _OutlineButton(
                                    icon: Icons.mode_comment_outlined,
                                    label: count == null || count == 0
                                        ? 'Opinions'
                                        : 'Opinions ($count)',
                                    onTap: () =>
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
  const _Header({
    required this.isSaved,
    required this.onToggleSave,
    required this.onHide,
  });

  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onHide;

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
            child: Text('Article',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          _IconButton(
              icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
              tooltip: isSaved ? 'Remove from saved' : 'Save',
              highlighted: isSaved,
              onTap: onToggleSave),
          const SizedBox(width: 8),
          _IconButton(
              icon: Icons.visibility_off_outlined,
              tooltip: 'Hide from feed',
              onTap: onHide),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.highlighted = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: highlighted
              ? HomeStyle.purple.withValues(alpha: 0.16)
              : HomeStyle.cardBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(
                color: highlighted
                    ? HomeStyle.purple.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon,
                  size: 21,
                  color: highlighted ? HomeStyle.purple : HomeStyle.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: HomeStyle.textPrimary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: HomeStyle.textPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
