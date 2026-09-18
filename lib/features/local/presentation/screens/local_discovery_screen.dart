import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/local_providers.dart';

/// Local 1-to-1 discovery (spec sections 3.1, 33, 63-64). Deliberately kept
/// visually distinct from professional People discovery (warm accent color,
/// no company/role framing) so it never reads as a networking feature — the
/// orange `AppColors.localAccent` carries that through even inside the
/// app-wide dark visual language.
class LocalDiscoveryScreen extends ConsumerWidget {
  const LocalDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localProfileAsync = ref.watch(myLocalProfileProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(onSettings: () => context.push(RoutePaths.localSetup)),
                  Expanded(
                    child: localProfileAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: e.toString()),
                      data: (localProfile) {
                        if (localProfile == null || !localProfile.enabled) {
                          return const _EnableLocalPrompt();
                        }
                        return const _CandidatesList();
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

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

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
            child: Text('Local',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          _IconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Local settings',
              onTap: onSettings),
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

class _EnableLocalPrompt extends StatelessWidget {
  const _EnableLocalPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                AppColors.localAccent,
                AppColors.localAccent.withValues(alpha: 0.4),
              ]),
              boxShadow:
                  HomeStyle.glow(AppColors.localAccent, opacity: 0.3, blur: 20),
            ),
            child: const Icon(Icons.near_me_outlined,
                size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Meet someone nearby',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: HomeStyle.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'New in town or just want a casual coffee, walk, or chat with someone compatible nearby? Turn on Local discovery to get started — always 1-to-1, never group meetups.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.5, height: 1.5, color: HomeStyle.textSecondary),
          ),
          const SizedBox(height: 26),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push(RoutePaths.localSetup),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.localAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Set up Local',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
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
      backgroundColor: HomeStyle.cardBase,
      color: AppColors.localAccent,
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: candidates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = candidates[i];
              return GradientBorderCard(
                radius: 18,
                gradient: LinearGradient(
                  colors: [
                    AppColors.localAccent.withValues(alpha: 0.26),
                    AppColors.localAccent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () =>
                    context.push(RoutePaths.localProfileDetailOf(c.profileId)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
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
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: HomeStyle.textPrimary)),
                            const SizedBox(height: 3),
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
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: HomeStyle.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
