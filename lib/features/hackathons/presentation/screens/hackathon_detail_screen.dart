import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../moderation/presentation/widgets/report_action_button.dart';
import '../../../profile/presentation/providers/profile_providers.dart' show myProfileProvider;
import '../../domain/team_card_action.dart';
import '../../domain/team_match.dart';
import '../providers/hackathon_providers.dart';
import '../widgets/invite_to_team_sheet.dart';
import '../widgets/team_card.dart';

/// "Find a Team" for one hackathon: every open team requirement, each with
/// a dynamic action (Join / Request pending / Already a member / Team full
/// / Invite) resolved per spec section 5 — never a one-size-fits-all button.
/// Includes quick role/skill/experience/status filters over the already-
/// fetched list (no separate search backend — extends the existing one).
class HackathonDetailScreen extends ConsumerStatefulWidget {
  const HackathonDetailScreen({super.key, required this.hackathonId});

  final String hackathonId;

  @override
  ConsumerState<HackathonDetailScreen> createState() => _HackathonDetailScreenState();
}

class _HackathonDetailScreenState extends ConsumerState<HackathonDetailScreen> {
  String? _roleFilter;
  String? _skillFilter;
  String? _statusFilter;

  List<TeamRequirement> _applyFilters(List<TeamRequirement> teams) {
    return teams.where((t) {
      if (_roleFilter != null) {
        final roles = t.roleRequirements.isNotEmpty ? t.roleRequirements.map((r) => r.roleName) : t.requiredRoles;
        if (!roles.contains(_roleFilter)) return false;
      }
      if (_skillFilter != null && !t.requiredSkillNames.contains(_skillFilter)) return false;
      if (_statusFilter == 'open' && !t.isOpen) return false;
      if (_statusFilter == 'full' && !t.isFull) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hackathonAsync = ref.watch(hackathonDetailProvider(widget.hackathonId));
    final teamsAsync = ref.watch(teamRequirementsProvider(widget.hackathonId));
    final myProfileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: const Text('Hackathon', style: TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
        actions: [
          ReportActionButton(targetType: ReportTargetType.hackathon, targetId: widget.hackathonId),
        ],
      ),
      body: hackathonAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (h) {
          return ResponsiveCenter(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(teamRequirementsProvider(widget.hackathonId));
                ref.invalidate(myTeamIdForHackathonProvider(widget.hackathonId));
                ref.invalidate(myPendingJoinRequestTeamIdsProvider(widget.hackathonId));
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.name, style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                    if (h.eventDate != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: HomeStyle.textSecondary),
                          const SizedBox(width: 6),
                          Text(DateFormat.yMMMd().format(h.eventDate!),
                              style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Find a team',
                            style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18, color: HomeStyle.purple),
                          label: const Text('Post a team', style: TextStyle(color: HomeStyle.purple)),
                          onPressed: () => context.push(RoutePaths.newTeamRequirementOf(widget.hackathonId), extra: h.name),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    teamsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load teams', style: TextStyle(color: HomeStyle.textSecondary)),
                      data: (teams) {
                        if (teams.isEmpty) {
                          return const EmptyState(icon: Icons.groups_2_outlined, title: 'No teams looking for members yet');
                        }
                        final filtered = _applyFilters(teams);
                        final mySkillNames = myProfileAsync.valueOrNull?.skills.map((s) => s.skill.name).toList() ?? const [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FiltersRow(
                              teams: teams,
                              roleFilter: _roleFilter,
                              skillFilter: _skillFilter,
                              statusFilter: _statusFilter,
                              onRoleChanged: (v) => setState(() => _roleFilter = v),
                              onSkillChanged: (v) => setState(() => _skillFilter = v),
                              onStatusChanged: (v) => setState(() => _statusFilter = v),
                            ),
                            const SizedBox(height: 10),
                            if (filtered.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                    child: Text('No teams match these filters', style: TextStyle(color: HomeStyle.textSecondary))),
                              )
                            else
                              for (final team in filtered)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _TeamCardHost(
                                    team: team,
                                    hackathonId: widget.hackathonId,
                                    mySkillNames: mySkillNames,
                                  ),
                                ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.teams,
    required this.roleFilter,
    required this.skillFilter,
    required this.statusFilter,
    required this.onRoleChanged,
    required this.onSkillChanged,
    required this.onStatusChanged,
  });

  final List<TeamRequirement> teams;
  final String? roleFilter;
  final String? skillFilter;
  final String? statusFilter;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onSkillChanged;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final roles = <String>{
      for (final t in teams) ...(t.roleRequirements.isNotEmpty ? t.roleRequirements.map((r) => r.roleName) : t.requiredRoles),
    }.toList()
      ..sort();
    final skills = <String>{for (final t in teams) ...t.requiredSkillNames}.toList()..sort();

    final chips = <(String, bool, VoidCallback)>[
      ('Open only', statusFilter == 'open', () => onStatusChanged(statusFilter == 'open' ? null : 'open')),
      ('Full', statusFilter == 'full', () => onStatusChanged(statusFilter == 'full' ? null : 'full')),
      for (final role in roles) (role, roleFilter == role, () => onRoleChanged(roleFilter == role ? null : role)),
      for (final skill in skills) (skill, skillFilter == skill, () => onSkillChanged(skillFilter == skill ? null : skill)),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, selected, onTap) = chips[i];
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected ? HomeStyle.brandGradient : null,
                  color: selected ? null : HomeStyle.cardBase,
                  borderRadius: BorderRadius.circular(100),
                  border: selected ? null : Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : HomeStyle.textSecondary)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TeamCardHost extends ConsumerStatefulWidget {
  const _TeamCardHost({required this.team, required this.hackathonId, required this.mySkillNames});

  final TeamRequirement team;
  final String hackathonId;
  final List<String> mySkillNames;

  @override
  ConsumerState<_TeamCardHost> createState() => _TeamCardHostState();
}

class _TeamCardHostState extends ConsumerState<_TeamCardHost> {
  bool _busy = false;

  Future<void> _handleAction(TeamCardAction action) async {
    final team = widget.team;
    if (action == TeamCardAction.inviteMembers) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: HomeStyle.cardBase,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => InviteToTeamSheet(teamRequirementId: team.id),
      );
      return;
    }
    if (action != TeamCardAction.join) return;

    setState(() => _busy = true);
    final ok = await ref.read(hackathonControllerProvider.notifier).requestToJoinTeam(team.id, widget.hackathonId);
    if (!mounted) return;
    setState(() => _busy = false);
    context.showSnack(ok ? 'Request sent' : 'Could not send request', isError: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final myTeamId = ref.watch(myTeamIdForHackathonProvider(widget.hackathonId)).valueOrNull;
    final pendingRequestIds = ref.watch(myPendingJoinRequestTeamIdsProvider(widget.hackathonId)).valueOrNull ?? {};
    final team = widget.team;

    final action = resolveTeamCardAction(
      team: team,
      myId: myId,
      hasPendingRequestForThisTeam: pendingRequestIds.contains(team.id),
      myTeamIdInHackathon: myTeamId,
    );

    return TeamCard(
      team: team,
      action: action,
      isBusy: _busy,
      matchResult: computeTeamMatchScore(team: team, mySkillNames: widget.mySkillNames),
      onTap: () => context.push(RoutePaths.teamDetailOf(team.id)),
      onAction: () => _handleAction(action),
    );
  }
}
