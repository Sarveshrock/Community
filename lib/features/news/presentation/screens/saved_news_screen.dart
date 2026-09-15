import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../providers/news_providers.dart';

class SavedNewsScreen extends ConsumerWidget {
  const SavedNewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedNewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved articles')),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(savedNewsProvider),
          child: savedAsync.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(savedNewsProvider)),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                    icon: Icons.bookmark_border, title: 'Nothing saved yet');
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = items[i];
                  return Card(
                    child: ListTile(
                      title: Text(n.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: n.source != null ? Text(n.source!) : null,
                      onTap: () {
                        ref
                            .read(newsControllerProvider.notifier)
                            .openArticle(n.url);
                        context.push(RoutePaths.newsDetail, extra: n);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.bookmark_remove_outlined),
                        onPressed: () => ref
                            .read(newsControllerProvider.notifier)
                            .unsave(n.url),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
