import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/skill.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/interview_practice_providers.dart';

/// Browse the mock-interview practice pool (spec-extension: Mock Interview
/// Matching). Setting up your own listing is a profile toggle, not postable
/// content, so — like Mentors — it isn't in the Create menu; it lives here.
class InterviewPracticeListScreen extends ConsumerWidget {
  const InterviewPracticeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolAsync = ref.watch(interviewPracticePoolProvider);
    final myProfileAsync = ref.watch(myInterviewPracticeProfileProvider);

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
                    profileAsync: myProfileAsync,
                    onMyRequests: () =>
                        context.push(RoutePaths.myInterviewPracticeRequests),
                    onEditProfile: () =>
                        context.push(RoutePaths.editInterviewPracticeProfile),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      backgroundColor: HomeStyle.cardBase,
                      color: HomeStyle.purple,
                      onRefresh: () async =>
                          ref.invalidate(interviewPracticePoolProvider),
                      child: poolAsync.when(
                        loading: () => const SkeletonList(),
                        error: (e, _) => ErrorState(
                            message: e.toString(),
                            onRetry: () =>
                                ref.invalidate(interviewPracticePoolProvider)),
                        data: (pool) {
                          if (pool.isEmpty) {
                            return const EmptyState(
                              icon: Icons.record_voice_over_outlined,
                              title: 'No one in the practice pool yet',
                              message:
                                  'Join the pool to find a mock-interview partner.',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: pool.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final p = pool[i];
                              return Material(
                                color: HomeStyle.cardBase,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => context.push(
                                      RoutePaths
                                          .interviewPracticePartnerDetailOf(
                                              p.profileId)),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.06)),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        UserAvatar(
                                            avatarUrl: p.avatarUrl,
                                            name: p.fullName ?? '?',
                                            radius: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  p.fullName ??
                                                      'Community member',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: HomeStyle
                                                          .textPrimary)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  p.topics.isNotEmpty
                                                      ? '${p.targetRole} · ${p.topics.join(', ')}'
                                                      : p.targetRole,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12.5,
                                                      color: HomeStyle
                                                          .textSecondary)),
                                            ],
                                          ),
                                        ),
                                        HomeChip(p.experienceLevel.label,
                                            accent: HomeStyle.cyan),
                                      ],
                                    ),
                                  ),
                                ),
                              );
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
  const _Header({
    required this.profileAsync,
    required this.onMyRequests,
    required this.onEditProfile,
  });

  final AsyncValue<InterviewPracticeProfile?> profileAsync;
  final VoidCallback onMyRequests;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final hasProfile = profileAsync.valueOrNull != null;
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
            child: Text('Mock Interviews',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          _IconButton(
              icon: Icons.assignment_outlined,
              tooltip: 'My requests',
              onTap: onMyRequests),
          const SizedBox(width: 8),
          _IconButton(
              icon: hasProfile ? Icons.edit_outlined : Icons.add_rounded,
              tooltip: hasProfile ? 'Edit my profile' : 'Join the pool',
              highlighted: true,
              onTap: onEditProfile),
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
