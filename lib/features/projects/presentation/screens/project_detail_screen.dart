import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../moderation/presentation/widgets/report_action_button.dart';
import '../providers/project_providers.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final interestedAsync = ref.watch(hasExpressedInterestProvider(projectId));
    final isLoading = ref.watch(projectControllerProvider).isLoading;
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(projectId: projectId),
                  Expanded(
                    child: projectAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: e.toString()),
                      data: (p) {
                        final isOwner = p.ownerId == myId;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.title,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: HomeStyle.textPrimary,
                                      letterSpacing: -0.3)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  HomeChip(p.collaborationType.label,
                                      accent: HomeStyle.violet),
                                  HomeChip(p.compensationType.label,
                                      accent: HomeStyle.green),
                                  if (p.category != null)
                                    HomeChip(p.category!,
                                        accent: HomeStyle.blue),
                                ],
                              ),
                              const SizedBox(height: 18),
                              if (p.description != null) ...[
                                Text(p.description!,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        height: 1.5,
                                        color: HomeStyle.textPrimary)),
                                const SizedBox(height: 18),
                              ],
                              if (p.durationDescription != null) ...[
                                const _SectionTitle('Duration'),
                                const SizedBox(height: 6),
                                Text(p.durationDescription!,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        color: HomeStyle.textSecondary)),
                                const SizedBox(height: 18),
                              ],
                              if (p.requiredSkillNames.isNotEmpty) ...[
                                const _SectionTitle('Skills needed'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final s in p.requiredSkillNames)
                                      HomeChip(s, accent: HomeStyle.cyan),
                                  ],
                                ),
                                const SizedBox(height: 18),
                              ],
                              if (!isOwner)
                                interestedAsync.when(
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                  data: (interested) => SizedBox(
                                    width: double.infinity,
                                    child: interested
                                        ? const _OutlineButton(
                                            label: 'Interest sent',
                                            onTap: null,
                                          )
                                        : _GradientButton(
                                            icon: Icons.handshake_outlined,
                                            label: 'I\'m interested',
                                            onTap: isLoading
                                                ? null
                                                : () => ref
                                                    .read(
                                                        projectControllerProvider
                                                            .notifier)
                                                    .expressInterest(
                                                        projectId, null),
                                          ),
                                  ),
                                ),
                              if (isOwner) ...[
                                const SizedBox(height: 8),
                                const _SectionTitle('Interested people'),
                                const SizedBox(height: 10),
                                Consumer(builder: (context, ref, _) {
                                  final interestsAsync = ref.watch(
                                      projectInterestsProvider(projectId));
                                  return interestsAsync.when(
                                    loading: () =>
                                        const LinearProgressIndicator(
                                            color: HomeStyle.purple),
                                    error: (_, __) => const Text(
                                        'Could not load interests',
                                        style: TextStyle(
                                            color: HomeStyle.textSecondary)),
                                    data: (interests) {
                                      if (interests.isEmpty) {
                                        return const Text(
                                          'No one has expressed interest yet.',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  HomeStyle.textSecondary),
                                        );
                                      }
                                      return Column(
                                        children: [
                                          for (final interest in interests)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: _InterestTile(
                                                interest: interest,
                                                onAccept: () => ref
                                                    .read(
                                                        projectControllerProvider
                                                            .notifier)
                                                    .respondToInterest(
                                                        projectId,
                                                        interest['id']
                                                            as String,
                                                        accept: true),
                                                onReject: () => ref
                                                    .read(
                                                        projectControllerProvider
                                                            .notifier)
                                                    .respondToInterest(
                                                        projectId,
                                                        interest['id']
                                                            as String,
                                                        accept: false),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  );
                                }),
                              ],
                            ],
                          ),
                        );
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
  const _Header({required this.projectId});

  final String projectId;

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
            child: Text('Project',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          ReportActionButton(
              targetType: ReportTargetType.project, targetId: projectId),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: HomeStyle.textPrimary));
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({this.icon, required this.label, required this.onTap});

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: onTap == null ? null : HomeStyle.brandGradient,
            color: onTap == null ? HomeStyle.cardBase : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: HomeStyle.textSecondary, fontWeight: FontWeight.w700)),
    );
  }
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({
    required this.interest,
    required this.onAccept,
    required this.onReject,
  });

  final Map<String, dynamic> interest;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final profile = interest['profiles'] as Map?;
    final status = interest['status'] as String? ?? 'pending';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeStyle.cardBase,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          UserAvatar(
            avatarUrl: profile?['avatar_url'] as String?,
            name: profile?['full_name'] as String? ?? '?',
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile?['full_name'] as String? ?? 'Community member',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: HomeStyle.textPrimary)),
                Text(status,
                    style: const TextStyle(
                        fontSize: 12, color: HomeStyle.textSecondary)),
              ],
            ),
          ),
          if (status == 'pending') ...[
            IconButton(
              icon: const Icon(Icons.check_circle,
                  color: HomeStyle.green),
              onPressed: onAccept,
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: HomeStyle.pink),
              onPressed: onReject,
            ),
          ],
        ],
      ),
    );
  }
}
