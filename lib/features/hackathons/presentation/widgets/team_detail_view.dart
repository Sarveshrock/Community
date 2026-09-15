import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/team_match.dart';

/// The team's full rendering — shared by the real, provider-backed
/// `TeamDetailScreen` and the Team Builder's live Preview step, so the two
/// can never visually drift apart. Every optional section is conditionally
/// rendered only when the team actually has that data — an old team
/// (posted before 0046_hackathon_team_details.sql) with only the original
/// fields renders exactly as it always did, with every new section simply
/// absent, never a blank space or a literal "null".
class TeamDetailView extends StatelessWidget {
  const TeamDetailView({
    super.key,
    required this.team,
    required this.hackathonName,
    this.hackathonEventDate,
    this.matchResult,
    this.primaryAction,
    this.organizerControls,
    this.memberActionBuilder,
  });

  final TeamRequirement team;
  final String hackathonName;
  final DateTime? hackathonEventDate;
  final TeamMatchResult? matchResult;

  /// Null in preview mode — shows a static "Preview" badge instead.
  final Widget? primaryAction;
  final Widget? organizerControls;

  /// Builds an optional trailing widget (e.g. "Remove") for one member row.
  final Widget? Function(TeamMemberInfo member)? memberActionBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(team: team, hackathonName: hackathonName, hackathonEventDate: hackathonEventDate),
        const SizedBox(height: 16),
        primaryAction ?? const _PreviewBadge(),
        const SizedBox(height: 18),
        _QuickInfoGrid(team: team),
        if (matchResult != null && matchResult!.hasAnyMatch) ...[
          const SizedBox(height: 18),
          _MatchCard(result: matchResult!),
        ],
        if ((team.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionHeader('What we\'re building'),
          Text(team.description!, style: const TextStyle(color: HomeStyle.textSecondary, height: 1.5)),
        ],
        if (team.members.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionHeader('Current team'),
          _MembersList(team: team, actionBuilder: memberActionBuilder),
        ],
        if (team.roleRequirements.isNotEmpty || team.requiredRoles.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionHeader('Looking for'),
          if (team.roleRequirements.isNotEmpty)
            _RolesList(roles: team.roleRequirements)
          else
            _ChipWrap(items: team.requiredRoles, accent: HomeStyle.purple),
        ],
        if (team.skillsHaveNames.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionHeader('Skills we have'),
          _ChipWrap(items: team.skillsHaveNames, accent: HomeStyle.cyan),
        ],
        if (team.requiredSkillNames.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionHeader('Skills we\'re looking for'),
          _ChipWrap(items: team.requiredSkillNames, accent: HomeStyle.blue),
        ],
        if (_hasAvailabilityInfo(team)) ...[
          const SizedBox(height: 20),
          const _SectionHeader('Availability & commitment'),
          _AvailabilitySection(team: team),
        ],
        const SizedBox(height: 20),
        const _SectionHeader('Collaboration'),
        _CollaborationSection(team: team),
        if (_hasPreferences(team)) ...[
          const SizedBox(height: 20),
          const _SectionHeader('Team preferences'),
          _PreferencesSection(team: team),
        ],
        if ((team.expectations ?? '').isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionHeader('What we expect from teammates'),
          Text(team.expectations!, style: const TextStyle(color: HomeStyle.textSecondary, height: 1.5)),
        ],
        if (team.hasProjectLinks) ...[
          const SizedBox(height: 20),
          const _SectionHeader('Project links'),
          _ProjectLinks(team: team),
        ],
        if (organizerControls != null) ...[
          const SizedBox(height: 20),
          organizerControls!,
        ],
      ],
    );
  }
}

bool _hasAvailabilityInfo(TeamRequirement team) =>
    (team.commitment ?? '').isNotEmpty || (team.preferredTimes ?? '').isNotEmpty || (team.timezone ?? '').isNotEmpty;

bool _hasPreferences(TeamRequirement team) =>
    (team.preferredExperienceLevel ?? '').isNotEmpty || team.teamCulture.isNotEmpty;

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: const Text('Preview — actions are disabled',
          style: TextStyle(color: HomeStyle.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.team, required this.hackathonName, required this.hackathonEventDate});
  final TeamRequirement team;
  final String hackathonName;
  final DateTime? hackathonEventDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 15, color: HomeStyle.purple),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hackathonEventDate != null
                    ? '$hackathonName · ${DateFormat.yMMMd().format(hackathonEventDate!.toLocal())}'
                    : hackathonName,
                style: const TextStyle(color: HomeStyle.purple, fontSize: 12.5, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(team.teamName,
            style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        if ((team.tagline ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(team.tagline!, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 13.5)),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusBadge(team: team),
            if ((team.projectStage ?? '').isNotEmpty) _PlainBadge(team.projectStage!),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.team});
  final TeamRequirement team;

  @override
  Widget build(BuildContext context) {
    final color = team.isFull || team.isClosed ? const Color(0xFFFB7185) : const Color(0xFF10D9A0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(team.statusLabel, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PlainBadge extends StatelessWidget {
  const _PlainBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11.5, color: HomeStyle.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
    );
  }
}

class _QuickInfoGrid extends StatelessWidget {
  const _QuickInfoGrid({required this.team});
  final TeamRequirement team;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.groups_2_outlined, 'Team size', '${team.memberCount} / ${team.teamSize} members'),
      (Icons.public_rounded, 'Collaboration', collaborationModeLabel(team.collaborationMode)),
      if ((team.commitment ?? '').isNotEmpty) (Icons.schedule_outlined, 'Commitment', team.commitment!),
      if ((team.preferredExperienceLevel ?? '').isNotEmpty)
        (Icons.trending_up_rounded, 'Experience', team.preferredExperienceLevel!),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        for (final (icon, label, value) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: HomeStyle.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 10.5, color: HomeStyle.textSecondary)),
                      Text(value,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.result});
  final TeamMatchResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: HomeStyle.brandGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${result.percent}% match',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Text('You match this team\'s: ${result.matchedSkills.join(', ')}',
              style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4)),
        ],
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.team, required this.actionBuilder});
  final TeamRequirement team;
  final Widget? Function(TeamMemberInfo member)? actionBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final member in team.members)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                UserAvatar(avatarUrl: member.avatarUrl, name: member.displayName, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.displayName,
                          style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                      if (member.headline != null)
                        Text(member.headline!, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (member.profileId == team.creatorId)
                  const _PlainBadge('Owner')
                else if (actionBuilder != null)
                  actionBuilder!(member) ?? const SizedBox.shrink(),
              ],
            ),
          ),
      ],
    );
  }
}

class _RolesList extends StatelessWidget {
  const _RolesList({required this.roles});
  final List<TeamRoleRequirement> roles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final role in roles)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
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
                    Expanded(
                      child: Text(role.roleName,
                          style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ),
                    if (role.priority != null) _PlainBadge(role.priority!),
                  ],
                ),
                if (role.experienceLevel != null) ...[
                  const SizedBox(height: 4),
                  Text(role.experienceLevel!, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                ],
                if ((role.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(role.description!, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12, height: 1.3)),
                ],
                if (role.skillNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in role.skillNames)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: HomeStyle.cyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(s, style: const TextStyle(fontSize: 10.5, color: HomeStyle.cyan, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items, required this.accent});
  final List<String> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Text(item, style: TextStyle(fontSize: 12.5, color: accent, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _AvailabilitySection extends StatelessWidget {
  const _AvailabilitySection({required this.team});
  final TeamRequirement team;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((team.commitment ?? '').isNotEmpty)
            _KeyValueRow('Commitment', team.commitment!),
          if ((team.preferredTimes ?? '').isNotEmpty)
            _KeyValueRow('Preferred times', team.preferredTimes!),
          if ((team.timezone ?? '').isNotEmpty) _KeyValueRow('Timezone', team.timezone!),
        ],
      ),
    );
  }
}

class _CollaborationSection extends StatelessWidget {
  const _CollaborationSection({required this.team});
  final TeamRequirement team;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KeyValueRow('Mode', collaborationModeLabel(team.collaborationMode)),
          if ((team.isInPerson || team.isHybrid) && (team.location ?? '').isNotEmpty)
            _KeyValueRow('Location', team.location!),
          if ((team.isOnline || team.isHybrid) && (team.communicationPlatform ?? '').isNotEmpty)
            _KeyValueRow('Communication', team.communicationPlatform!),
        ],
      ),
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({required this.team});
  final TeamRequirement team;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((team.preferredExperienceLevel ?? '').isNotEmpty) ...[
          Text('Preferred experience: ${team.preferredExperienceLevel}',
              style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
        ],
        if (team.teamCulture.isNotEmpty) _ChipWrap(items: team.teamCulture, accent: HomeStyle.violet),
      ],
    );
  }
}

class _ProjectLinks extends StatelessWidget {
  const _ProjectLinks({required this.team});
  final TeamRequirement team;

  @override
  Widget build(BuildContext context) {
    final links = <(IconData, String, String?)>[
      (Icons.code_rounded, 'GitHub', team.githubUrl),
      (Icons.design_services_outlined, 'Figma', team.figmaUrl),
      (Icons.language_rounded, 'Website', team.websiteUrl),
      (Icons.play_circle_outline, 'Demo', team.demoUrl),
      (Icons.slideshow_outlined, 'Pitch deck', team.pitchDeckUrl),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label, url) in links)
          if (url != null && url.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: HomeStyle.blue),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(fontSize: 12, color: HomeStyle.textPrimary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: HomeStyle.textSecondary, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
