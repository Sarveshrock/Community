import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/match_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../connections/domain/entities/connection.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../../../profile/domain/entities/profile.dart';
import 'people_style.dart';

/// Card shown in People discovery (All and Recommended alike) — one shared
/// component for both, distinguished only by whether [matchScore] is
/// passed, so the badge only ever appears where a real AI score exists.
class PersonCard extends ConsumerWidget {
  const PersonCard(
      {super.key, required this.profile, this.matchScore, this.matchReason});

  final Profile profile;
  final double? matchScore;
  final String? matchReason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ring = PeopleStyle.ringFor(profile.id);
    final presence = BuddyPresence.fromUpdatedAt(profile.updatedAt);
    final skills = profile.skills;
    const maxSkills = 6;
    final overflowCount = skills.length > maxSkills ? skills.length - maxSkills : 0;

    return Container(
      decoration: BoxDecoration(
        color: PeopleStyle.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PeopleStyle.border),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(RoutePaths.personDetailOf(profile.id)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [ring, ring.withValues(alpha: 0.3)]),
                        boxShadow: PeopleStyle.glow(ring, opacity: 0.3, blur: 10),
                      ),
                      child: UserAvatar(
                        avatarUrl: profile.avatarUrl,
                        name: profile.displayName,
                        radius: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            getDisplayName(ref,
                                profileId: profile.id, mainName: profile.displayName),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: PeopleStyle.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.work_outline_rounded,
                                  size: 13, color: PeopleStyle.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  profile.headline,
                                  style: const TextStyle(
                                      fontSize: 12.5, color: PeopleStyle.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (profile.totalItExperienceMonths > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              Formatters.experienceFromMonths(profile.totalItExperienceMonths),
                              style: const TextStyle(fontSize: 12, color: PeopleStyle.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (matchScore != null) ...[
                          MatchBadge(score: matchScore!, reason: matchReason),
                          const SizedBox(height: 8),
                        ],
                        _PresenceLabel(presence: presence),
                        const SizedBox(height: 8),
                        _ConnectButton(profileId: profile.id),
                      ],
                    ),
                  ],
                ),
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in skills.take(maxSkills))
                        _SkillChip(s.skill.name),
                      if (overflowCount > 0) _SkillChip('+$overflowCount'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresenceLabel extends StatelessWidget {
  const _PresenceLabel({required this.presence});

  final BuddyPresence presence;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: presence.label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: presence.isOnline ? PeopleStyle.online : PeopleStyle.offline,
              boxShadow: presence.isOnline
                  ? [BoxShadow(color: PeopleStyle.online.withValues(alpha: 0.6), blurRadius: 4)]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            presence.label,
            style: const TextStyle(fontSize: 11.5, color: PeopleStyle.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: PeopleStyle.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.5, color: PeopleStyle.textSecondary, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Compact icon-only Connect affordance — reuses the exact same
/// connection-state provider/controller as the full "Connect"/"Message"
/// row on the profile detail screen (`_OtherProfileActions`), just with a
/// smaller footprint suited to a list card. Nested inside the card's own
/// `InkWell`: Flutter's normal hit-testing already lets this button's own
/// tap win over the card's tap-to-open-profile, so no gesture plumbing is
/// needed beyond the usual widget nesting.
class _ConnectButton extends ConsumerWidget {
  const _ConnectButton({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionWithProvider(profileId));
    final isLoading = ref.watch(connectionControllerProvider).isLoading;

    return connectionAsync.when(
      loading: () => const SizedBox(width: 32, height: 32),
      error: (_, __) => const SizedBox.shrink(),
      data: (connection) {
        switch (connection?.status) {
          case ConnectionStatus.pending:
            return _iconButton(
              icon: Icons.hourglass_top_rounded,
              tooltip: 'Pending',
              color: PeopleStyle.textMuted,
              onTap: null,
            );
          case ConnectionStatus.accepted:
            return _iconButton(
              icon: Icons.check_circle_rounded,
              tooltip: 'Connected',
              color: PeopleStyle.online,
              onTap: null,
            );
          default:
            return _iconButton(
              icon: Icons.person_add_alt_1_rounded,
              tooltip: 'Connect',
              color: PeopleStyle.textPrimary,
              gradient: true,
              onTap: isLoading
                  ? null
                  : () => ref
                      .read(connectionControllerProvider.notifier)
                      .sendRequest(profileId),
            );
        }
      },
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    VoidCallback? onTap,
    bool gradient = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient ? PeopleStyle.selectedChipGradient : null,
          color: gradient ? null : Colors.white.withValues(alpha: 0.06),
          border: gradient ? null : Border.all(color: PeopleStyle.border),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
