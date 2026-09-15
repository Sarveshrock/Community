import 'package:flutter/material.dart';

import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/team_card_action.dart';
import '../../domain/team_match.dart';

/// Compact discovery-list card for a team requirement — team name,
/// hackathon, project idea, member count, looking-for roles, top skills,
/// experience preference, and status. Extracted from
/// `hackathon_detail_screen.dart`'s old inline `_TeamCard` and redesigned
/// to match Communeo's dark visual language.
class TeamCard extends StatelessWidget {
  const TeamCard({
    super.key,
    required this.team,
    required this.action,
    required this.onTap,
    required this.onAction,
    this.isBusy = false,
    this.matchResult,
  });

  final TeamRequirement team;
  final TeamCardAction action;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final bool isBusy;
  final TeamMatchResult? matchResult;

  @override
  Widget build(BuildContext context) {
    final roleNames = team.roleRequirements.isNotEmpty
        ? team.roleRequirements.map((r) => r.roleName).toList()
        : team.requiredRoles;
    final topSkills = team.requiredSkillNames.take(3).toList();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(team.teamName,
                        style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (matchResult != null && matchResult!.hasAnyMatch) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(gradient: HomeStyle.brandGradient, borderRadius: BorderRadius.circular(100)),
                      child: Text('${matchResult!.percent}%',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
              if ((team.tagline ?? team.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(team.tagline ?? team.description!,
                    style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Badge('${team.memberCount}/${team.teamSize} members'),
                  if ((team.commitment ?? '').isNotEmpty) _Badge(team.commitment!),
                  if ((team.preferredExperienceLevel ?? '').isNotEmpty) _Badge(team.preferredExperienceLevel!),
                ],
              ),
              if (roleNames.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Looking for: ', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                    Expanded(
                      child: Text(roleNames.join(' • '),
                          style: const TextStyle(color: HomeStyle.purple, fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
              if (topSkills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in topSkills)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: HomeStyle.cyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(100)),
                        child: Text(skill, style: const TextStyle(fontSize: 11, color: HomeStyle.cyan, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: team.isFull || team.isClosed ? const Color(0xFFFB7185) : const Color(0xFF10D9A0)),
                  const SizedBox(width: 6),
                  Text(team.statusLabel, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
                  const Spacer(),
                  SizedBox(
                    height: 34,
                    child: action == TeamCardAction.inviteMembers
                        ? OutlinedButton.icon(
                            onPressed: onAction,
                            icon: const Icon(Icons.person_add_alt_1, size: 14),
                            label: const Text('Invite', style: TextStyle(fontSize: 12.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HomeStyle.purple,
                              side: BorderSide(color: HomeStyle.purple.withValues(alpha: 0.5)),
                            ),
                          )
                        : FilledButton(
                            onPressed: (action.isEnabled && !isBusy) ? onAction : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: HomeStyle.purple,
                              disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            child: isBusy
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(action.label, style: const TextStyle(fontSize: 12.5)),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10.5, color: HomeStyle.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}
