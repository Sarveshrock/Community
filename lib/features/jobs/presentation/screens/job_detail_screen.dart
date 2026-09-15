import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../moderation/presentation/widgets/report_dialog.dart';
import '../providers/job_providers.dart';
import '../widgets/job_detail_view.dart';

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  Future<void> _handlePrimaryAction(BuildContext context, WidgetRef ref, JobActionState state, Job job) async {
    if (state == JobActionState.applyInternal) {
      context.push(RoutePaths.jobApplyOf(jobId));
      return;
    }
    if (state == JobActionState.applyExternal && job.applicationUrl != null && job.applicationUrl!.isNotEmpty) {
      final uri = Uri.tryParse(job.applicationUrl!);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _closeOrReopen(BuildContext context, WidgetRef ref, Job job) async {
    final controller = ref.read(jobControllerProvider.notifier);
    final ok = job.isClosed ? await controller.reopenJob(jobId) : await controller.closeJob(jobId);
    if (context.mounted) {
      context.showSnack(
        ok ? (job.isClosed ? 'Job reopened' : 'Applications closed') : 'Could not update job',
        isError: !ok,
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this job posting?',
      message: 'This permanently removes the job and its applications. This can\'t be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref.read(jobControllerProvider.notifier).deleteJob(jobId);
    if (!context.mounted) return;
    if (ok) {
      context.pop();
    } else {
      context.showSnack('Could not delete job', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    final appliedAsync = ref.watch(hasAppliedProvider(jobId));
    final isActionLoading = ref.watch(jobControllerProvider).isLoading;
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: jobAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (job) {
          final isOwner = job.posterId == myId;
          final state = resolveJobActionState(
            job: job,
            myId: myId,
            hasApplied: appliedAsync.valueOrNull ?? false,
          );

          return SafeArea(
            child: Stack(
              children: [
                JobDetailView(
                  job: job,
                  actionState: state,
                  isActionLoading: isActionLoading,
                  onPrimaryAction: () => _handlePrimaryAction(context, ref, state, job),
                  organizerControls: isOwner
                      ? _OrganizerControls(
                          jobId: jobId,
                          job: job,
                          onToggleStatus: () => _closeOrReopen(context, ref, job),
                          onDelete: () => _delete(context, ref),
                        )
                      : null,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: () => context.pop()),
                ),
                if (!isOwner)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _RoundIconButton(
                      icon: Icons.flag_outlined,
                      onTap: () => showReportDialog(context, targetType: ReportTargetType.job, targetId: jobId),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
  }
}

class _OrganizerControls extends ConsumerWidget {
  const _OrganizerControls({
    required this.jobId,
    required this.job,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final String jobId;
  final Job job;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Manage this job', style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.editJobOf(jobId)),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeStyle.purple,
                  side: BorderSide(color: HomeStyle.purple.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onToggleStatus,
                icon: Icon(job.isClosed ? Icons.play_circle_outline : Icons.pause_circle_outline, size: 16),
                label: Text(job.isClosed ? 'Reopen' : 'Close'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeStyle.blue,
                  side: BorderSide(color: HomeStyle.blue.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFB7185),
                  side: const BorderSide(color: Color(0xFFFB7185)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Applicants', style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        Consumer(builder: (context, ref, _) {
          final applicationsAsync = ref.watch(jobApplicationsProvider(jobId));
          return applicationsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Could not load applicants', style: TextStyle(color: HomeStyle.textSecondary)),
            data: (applications) {
              if (applications.isEmpty) {
                return const Text('No applicants yet.', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 13));
              }
              return Column(
                children: [for (final app in applications) _ApplicantTile(jobId: jobId, applicant: app)],
              );
            },
          );
        }),
      ],
    );
  }
}

class _ApplicantTile extends ConsumerWidget {
  const _ApplicantTile({required this.jobId, required this.applicant});

  final String jobId;
  final JobApplicant applicant;

  Future<void> _viewFile(BuildContext context, WidgetRef ref, String path) async {
    final url = await ref.read(jobControllerProvider.notifier).getResumeSignedUrl(path);
    if (url == null) {
      if (context.mounted) context.showSnack('Could not open file', isError: true);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(avatarUrl: applicant.avatarUrl, name: applicant.fullName ?? '?', radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(applicant.fullName ?? 'Community member',
                        style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Text(applicant.status,
                        style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (status) =>
                    ref.read(jobControllerProvider.notifier).updateApplicationStatus(jobId, applicant.applicationId, status),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'reviewing', child: Text('Mark reviewing')),
                  PopupMenuItem(value: 'shortlisted', child: Text('Shortlist')),
                  PopupMenuItem(value: 'accepted', child: Text('Accept')),
                  PopupMenuItem(value: 'rejected', child: Text('Reject')),
                ],
              ),
            ],
          ),
          if (applicant.resumePath != null || applicant.portfolioPath != null || applicant.githubUrl != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (applicant.resumePath != null)
                  _LinkChip(label: 'Resume', onTap: () => _viewFile(context, ref, applicant.resumePath!)),
                if (applicant.portfolioPath != null)
                  _LinkChip(label: 'Portfolio', onTap: () => _viewFile(context, ref, applicant.portfolioPath!)),
                if (applicant.githubUrl != null)
                  _LinkChip(
                    label: 'GitHub',
                    onTap: () async {
                      final uri = Uri.tryParse(applicant.githubUrl!);
                      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeStyle.purple.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label, style: const TextStyle(color: HomeStyle.purple, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
