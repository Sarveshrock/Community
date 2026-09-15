import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../profile/presentation/providers/profile_providers.dart' show myProfileProvider;
import '../../domain/team_match.dart';
import '../providers/hackathon_providers.dart';
import '../widgets/team_detail_view.dart';

/// The "Team Page": overview, members (owner can remove; clickable into
/// profiles), the team's private chat, and Edit/Leave/Delete actions —
/// scoped to what the viewer's role actually allows.
class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamRequirementId});

  final String teamRequirementId;

  Future<void> _leave(BuildContext context, WidgetRef ref, String hackathonId) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Leave team?',
      message: 'Are you sure you want to leave this team?',
      confirmLabel: 'Leave',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref.read(hackathonControllerProvider.notifier).leaveTeam(teamRequirementId, hackathonId);
    if (!context.mounted) return;
    if (ok) {
      context.showSnack('You left the team');
      context.pop();
    } else {
      final error = ref.read(hackathonControllerProvider).error;
      context.showSnack(error?.toString() ?? 'Could not leave the team', isError: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String hackathonId) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete team?',
      message: 'Are you sure you want to delete this team? This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref.read(hackathonControllerProvider.notifier).deleteTeam(teamRequirementId, hackathonId);
    if (!context.mounted) return;
    if (ok) {
      context.showSnack('Team deleted');
      context.pop();
    } else {
      final error = ref.read(hackathonControllerProvider).error;
      context.showSnack(error?.toString() ?? 'Could not delete the team', isError: true);
    }
  }

  Future<void> _removeMember(BuildContext context, WidgetRef ref, String hackathonId, TeamMemberInfo member) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${member.displayName}?',
      message: 'They\'ll be removed from the team and its chat. They can request to join again later.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !context.mounted) return;
    final ok =
        await ref.read(hackathonControllerProvider.notifier).removeMember(teamRequirementId, member.profileId, hackathonId);
    if (!context.mounted) return;
    context.showSnack(ok ? 'Member removed' : 'Could not remove member', isError: !ok);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamDetailProvider(teamRequirementId));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final isBusy = ref.watch(hackathonControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: teamAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(teamDetailProvider(teamRequirementId))),
        data: (team) {
          final isOwner = team.isOwner(myId);
          final isMember = team.isMember(myId);
          final hackathonAsync = ref.watch(hackathonDetailProvider(team.hackathonId));
          final myProfileAsync = ref.watch(myProfileProvider);
          final mySkillNames = myProfileAsync.valueOrNull?.skills.map((s) => s.skill.name).toList() ?? const [];

          return SafeArea(
            child: Stack(
              children: [
                ResponsiveCenter(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(teamDetailProvider(teamRequirementId)),
                    child: TeamDetailView(
                      team: team,
                      hackathonName: hackathonAsync.valueOrNull?.name ?? '',
                      hackathonEventDate: hackathonAsync.valueOrNull?.eventDate,
                      matchResult: isMember ? null : computeTeamMatchScore(team: team, mySkillNames: mySkillNames),
                      primaryAction: _PrimaryAction(
                        team: team,
                        isOwner: isOwner,
                        isMember: isMember,
                        onChat: () => context.push(RoutePaths.teamChatOf(team.id), extra: team.teamName),
                      ),
                      memberActionBuilder: isOwner
                          ? (member) => member.profileId == myId
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.person_remove_outlined, size: 18, color: HomeStyle.textSecondary),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: isBusy ? null : () => _removeMember(context, ref, team.hackathonId, member),
                                )
                          : null,
                      organizerControls: (isOwner || isMember)
                          ? _ManageSection(
                              isOwner: isOwner,
                              isBusy: isBusy,
                              onEdit: () => context.push(RoutePaths.editTeamRequirementOf(team.id)),
                              onDelete: () => _delete(context, ref, team.hackathonId),
                              onLeave: () => _leave(context, ref, team.hackathonId),
                            )
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.pop(),
                      child: const SizedBox(width: 40, height: 40, child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20)),
                    ),
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

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.team, required this.isOwner, required this.isMember, required this.onChat});

  final TeamRequirement team;
  final bool isOwner;
  final bool isMember;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    if (!isMember) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onChat,
          child: Container(
            decoration: BoxDecoration(
              gradient: HomeStyle.brandGradient,
              borderRadius: BorderRadius.circular(100),
              boxShadow: HomeStyle.glow(HomeStyle.purple, opacity: 0.3),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Team chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageSection extends StatelessWidget {
  const _ManageSection({
    required this.isOwner,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
    required this.onLeave,
  });

  final bool isOwner;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Leave team'),
          onPressed: isBusy ? null : onLeave,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit team'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeStyle.purple,
                  side: BorderSide(color: HomeStyle.purple.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onDelete,
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
      ],
    );
  }
}
