import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../providers/startup_providers.dart';

class StartupsListScreen extends ConsumerWidget {
  const StartupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupsAsync = ref.watch(startupsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Startups')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RoutePaths.newStartup),
        child: const Icon(Icons.add),
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(startupsListProvider),
          child: startupsAsync.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(startupsListProvider)),
            data: (startups) {
              if (startups.isEmpty) {
                return const EmptyState(
                    icon: Icons.rocket_launch_outlined,
                    title: 'No startups yet',
                    message: 'Share yours and find co-founders.');
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: startups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final s = startups[i];
                  return Card(
                    child: ListTile(
                      onTap: () =>
                          context.push(RoutePaths.startupDetailOf(s.id)),
                      leading: UserAvatar(
                          avatarUrl: s.logoUrl, name: s.name, radius: 24),
                      title: Text(s.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([s.industry, s.stage]
                          .whereType<String>()
                          .join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
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
