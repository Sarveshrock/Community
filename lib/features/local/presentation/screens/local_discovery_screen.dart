import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../providers/local_providers.dart';

/// Local 1-to-1 discovery (spec sections 3.1, 33, 63-64). Deliberately kept
/// visually distinct from professional People discovery (warm accent color,
/// no company/role framing) so it never reads as a networking feature.
class LocalDiscoveryScreen extends ConsumerWidget {
  const LocalDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localProfileAsync = ref.watch(myLocalProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local'),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(RoutePaths.localSetup)),
        ],
      ),
      body: localProfileAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (localProfile) {
          if (localProfile == null || !localProfile.enabled) {
            return _EnableLocalPrompt();
          }
          return const _CandidatesList();
        },
      ),
    );
  }
}

class _EnableLocalPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.near_me_outlined,
                size: 64, color: AppColors.localAccent),
            const SizedBox(height: 16),
            Text(
              'Meet someone nearby',
              style: context.textStyles.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'New in town or just want a casual coffee, walk, or chat with someone compatible nearby? Turn on Local discovery to get started — always 1-to-1, never group meetups.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.localAccent),
              onPressed: () => context.push(RoutePaths.localSetup),
              child: const Text('Set up Local'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidatesList extends ConsumerWidget {
  const _CandidatesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidatesAsync = ref.watch(localCandidatesProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(localCandidatesProvider),
      child: candidatesAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(localCandidatesProvider)),
        data: (candidates) {
          if (candidates.isEmpty) {
            return const EmptyState(
              icon: Icons.explore_off_outlined,
              title: 'No one nearby right now',
              message: 'Check back later, or widen your radius in settings.',
            );
          }
          return ResponsiveCenter(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = candidates[i];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context
                        .push(RoutePaths.localProfileDetailOf(c.profileId)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          UserAvatar(
                              avatarUrl: c.avatarUrl,
                              name: c.displayName,
                              radius: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.displayName,
                                    style: context.textStyles.titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.near_me,
                                        size: 12, color: AppColors.localAccent),
                                    const SizedBox(width: 4),
                                    Text(c.distanceBucket,
                                        style: const TextStyle(
                                            color: AppColors.localAccent,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12)),
                                  ],
                                ),
                                if (c.bio != null && c.bio!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(c.bio!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textStyles.bodySmall),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
