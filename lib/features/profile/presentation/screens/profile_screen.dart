import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../connections/domain/entities/connection.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../intents/presentation/providers/intent_providers.dart';
import '../../../mentorship/presentation/providers/mentor_providers.dart';
import '../../../messaging/presentation/utils/open_direct_conversation.dart';
import '../../../moderation/presentation/widgets/report_dialog.dart';
import '../../../posts/presentation/providers/post_providers.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../providers/profile_providers.dart';
import '../widgets/add_proof_sheet.dart';
import '../widgets/add_tags_sheet.dart';

/// Professional profile (spec section 62) — UI redesigned to match the
/// app's premium dark visual language (`HomeStyle`/`GlowBackdrop`, already
/// used by Home/Discover/Buddies/People), same data and behavior as
/// before: the caller's own profile with edit/settings affordances when
/// [profileId] is null, or a read-only view with Connect/Message/Block/
/// Report for anyone else.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.profileId});

  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final isOwnProfile = profileId == null || profileId == myId;

    final profileAsync = isOwnProfile
        ? ref.watch(myProfileProvider)
        : ref.watch(profileByIdProvider(profileId!));
    final isBlocked = isOwnProfile
        ? false
        : ref.watch(isBlockedByMeProvider(profileId!)).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              maxWidth: 480,
              child: profileAsync.when(
                loading: () => Column(
                  children: [
                    _Header(isOwnProfile: isOwnProfile, otherProfileId: profileId, isBlocked: isBlocked),
                    const Expanded(child: SkeletonList()),
                  ],
                ),
                error: (e, _) => Column(
                  children: [
                    _Header(isOwnProfile: isOwnProfile, otherProfileId: profileId, isBlocked: isBlocked),
                    Expanded(child: ErrorState(message: e.toString())),
                  ],
                ),
                data: (profile) {
                  if (profile == null) {
                    return Column(
                      children: [
                        _Header(isOwnProfile: isOwnProfile, otherProfileId: profileId, isBlocked: isBlocked),
                        const Expanded(child: ErrorState(message: 'Profile not found')),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(isOwnProfile: isOwnProfile, otherProfileId: profileId, isBlocked: isBlocked),
                        const SizedBox(height: 4),
                        _HeroCard(profile: profile, isOwnProfile: isOwnProfile),
                        const SizedBox(height: 16),
                        if (isOwnProfile) ...[
                          const _MentorEntryCard(),
                          const SizedBox(height: 12),
                          const _IntentEntryCard(),
                          const SizedBox(height: 16),
                        ],
                        if (profile.careerGoals != null && profile.careerGoals!.isNotEmpty)
                          _SectionCard(
                            icon: Icons.track_changes_rounded,
                            accent: HomeStyle.purple,
                            title: 'Looking for',
                            onEdit: isOwnProfile ? () => context.push(RoutePaths.editProfile) : null,
                            child: Text(profile.careerGoals!,
                                style: const TextStyle(color: HomeStyle.textSecondary, height: 1.4)),
                          ),
                        _SectionCard(
                          icon: Icons.work_outline_rounded,
                          accent: HomeStyle.blue,
                          title: 'Experience',
                          onEdit: isOwnProfile ? () => context.push(RoutePaths.editProfile) : null,
                          child: Text(
                            Formatters.experienceFromMonths(profile.totalItExperienceMonths),
                            style: const TextStyle(color: HomeStyle.textSecondary),
                          ),
                        ),
                        _SectionCard(
                          icon: Icons.code_rounded,
                          accent: HomeStyle.cyan,
                          title: 'Skills',
                          onEdit: isOwnProfile ? () => context.push(RoutePaths.editProfile) : null,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in profile.skills) _Pill(s.skill.name),
                              if (isOwnProfile)
                                _AddPill(
                                  label: 'Add skills',
                                  onTap: () => showAddSkillsSheet(context,
                                      alreadySelected: profile.skills.map((s) => s.skill.id).toSet()),
                                ),
                            ],
                          ),
                        ),
                        _SectionCard(
                          icon: Icons.favorite_border_rounded,
                          accent: HomeStyle.pink,
                          title: 'Interests',
                          onEdit: isOwnProfile ? () => context.push(RoutePaths.editProfile) : null,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final i in profile.interests) _Pill(i.name),
                              if (isOwnProfile)
                                _AddPill(
                                  label: 'Add interests',
                                  onTap: () => showAddInterestsSheet(context,
                                      alreadySelected: profile.interests.map((i) => i.id).toSet()),
                                ),
                            ],
                          ),
                        ),
                        _ProofOfSkillsSection(isOwnProfile: isOwnProfile),
                        _SectionCard(
                          icon: Icons.description_outlined,
                          accent: HomeStyle.amber,
                          title: 'Posts',
                          child: _PostsList(profileId: profile.id, isOwnProfile: isOwnProfile),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.isOwnProfile, required this.otherProfileId, required this.isBlocked});

  final bool isOwnProfile;
  final String? otherProfileId;
  final bool isBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          _IconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOwnProfile ? 'My Profile' : 'Profile',
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 360 ? 22 : 25,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOwnProfile ? 'Your space, your story' : 'Community member',
                  style: const TextStyle(fontSize: 12.5, color: HomeStyle.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOwnProfile)
            _IconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              highlighted: true,
              onTap: () => context.push(RoutePaths.settings),
            )
          else
            _IconButton(
              icon: Icons.more_vert_rounded,
              tooltip: 'More',
              onTap: () => _showMoreMenu(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _showMoreMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isBlocked ? Icons.person_add_alt_1_outlined : Icons.block_outlined,
                  color: HomeStyle.textPrimary),
              title: Text(isBlocked ? 'Unblock' : 'Block',
                  style: const TextStyle(color: HomeStyle.textPrimary)),
              onTap: () => Navigator.of(context).pop(isBlocked ? 'unblock' : 'block'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: HomeStyle.textPrimary),
              title: const Text('Report', style: TextStyle(color: HomeStyle.textPrimary)),
              onTap: () => Navigator.of(context).pop('report'),
            ),
          ],
        ),
      ),
    );
    if (action == null || otherProfileId == null || !context.mounted) return;
    if (action == 'block') {
      final ok = await ref.read(connectionControllerProvider.notifier).blockUser(otherProfileId!);
      if (context.mounted) context.showSnack(ok ? 'User blocked' : 'Could not block user', isError: !ok);
    } else if (action == 'unblock') {
      final ok = await ref.read(connectionControllerProvider.notifier).unblockUser(otherProfileId!);
      if (context.mounted) context.showSnack(ok ? 'User unblocked' : 'Could not unblock user', isError: !ok);
    } else if (action == 'report') {
      if (context.mounted) {
        showReportDialog(context, targetType: ReportTargetType.profile, targetId: otherProfileId!);
      }
    }
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tooltip, this.onTap, this.highlighted = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: highlighted ? HomeStyle.brandGradient : null,
            color: highlighted ? null : HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(13),
            border: highlighted ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: highlighted ? HomeStyle.glow(HomeStyle.purple, opacity: 0.3) : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: onTap,
              child: Icon(icon, size: 21, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.profile, required this.isOwnProfile});

  final Profile profile;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = BuddyPresence.fromUpdatedAt(profile.updatedAt);
    return GradientBorderCard(
      radius: 26,
      gradient: LinearGradient(
        colors: [HomeStyle.blue.withValues(alpha: 0.30), HomeStyle.purple.withValues(alpha: 0.18)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glowColor: HomeStyle.purple,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: HomeStyle.brandGradient,
                        boxShadow: HomeStyle.glow(HomeStyle.purple, opacity: 0.35, blur: 14),
                      ),
                      child: UserAvatar(avatarUrl: profile.avatarUrl, name: profile.displayName, radius: 38),
                    ),
                    if (presence.isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF22D98A),
                            border: Border.all(color: HomeStyle.cardBase, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isOwnProfile
                                  ? profile.displayName
                                  : getDisplayName(ref, profileId: profile.id, mainName: profile.displayName),
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w800, color: HomeStyle.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOwnProfile)
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => context.push(RoutePaths.editProfile),
                              child: Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HomeStyle.purple.withValues(alpha: 0.16),
                                  border: Border.all(color: HomeStyle.purple.withValues(alpha: 0.5)),
                                ),
                                child: const Icon(Icons.edit_outlined, size: 14, color: HomeStyle.purple),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.work_outline_rounded, size: 14, color: HomeStyle.blue),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(profile.headline,
                                style: const TextStyle(fontSize: 13, color: HomeStyle.blue),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (profile.city != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: HomeStyle.textSecondary),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                [profile.city, profile.country].whereType<String>().join(', '),
                                style: const TextStyle(fontSize: 12.5, color: HomeStyle.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (profile.bio != null && profile.bio!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(profile.bio!, style: const TextStyle(color: HomeStyle.textSecondary, height: 1.4)),
            ],
            const SizedBox(height: 16),
            if (isOwnProfile) ...[
              Row(
                children: [
                  Expanded(
                    child: _OutlineActionButton(
                      icon: Icons.edit_outlined,
                      label: 'Edit profile',
                      onTap: () => context.push(RoutePaths.editProfile),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GradientActionButton(
                      icon: Icons.add_rounded,
                      label: 'Create post',
                      onTap: () => context.push(RoutePaths.newPost),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _StatsRow(profileId: profile.id),
            ] else
              _OtherProfileActions(otherProfileId: profile.id),
          ],
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: HomeStyle.purple.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: HomeStyle.purple),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: HomeStyle.purple, fontWeight: FontWeight.w700, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            gradient: HomeStyle.brandGradient,
            borderRadius: BorderRadius.circular(100),
            boxShadow: HomeStyle.glow(HomeStyle.purple, opacity: 0.32),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Only real, already-tracked counts (spec: never invent a statistic that
/// doesn't exist). "Profile views" and a generic "Saved" count have no
/// backing anywhere in this app — the only real, existing ones are the
/// caller's own posts and accepted connections.
class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsCount = ref.watch(authorPostsProvider(profileId)).valueOrNull?.length;
    final connectionsCount = ref.watch(buddiesProvider).valueOrNull?.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(value: postsCount, label: 'Posts'),
        const _StatDivider(),
        _StatItem(value: connectionsCount, label: 'Connections'),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.08));
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value == null ? '—' : '$value',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: HomeStyle.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11.5, color: HomeStyle.textSecondary)),
      ],
    );
  }
}

class _OtherProfileActions extends ConsumerWidget {
  const _OtherProfileActions({required this.otherProfileId});

  final String otherProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionWithProvider(otherProfileId));
    final isLoading = ref.watch(connectionControllerProvider).isLoading;

    return Row(
      children: [
        Expanded(
          child: connectionAsync.when(
            loading: () => const SizedBox(height: 46),
            error: (_, __) => const SizedBox.shrink(),
            data: (connection) {
              switch (connection?.status) {
                case ConnectionStatus.pending:
                  return _OutlineActionButton(icon: Icons.hourglass_top_rounded, label: 'Pending', onTap: () {});
                case ConnectionStatus.accepted:
                  return _OutlineActionButton(
                      icon: Icons.check_circle_outline_rounded, label: 'Connected', onTap: () {});
                default:
                  return _GradientActionButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Connect',
                    onTap: isLoading
                        ? () {}
                        : () => ref.read(connectionControllerProvider.notifier).sendRequest(otherProfileId),
                  );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OutlineActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Message',
            onTap: () => openDirectConversation(context, ref, otherProfileId),
          ),
        ),
      ],
    );
  }
}

/// The Profile page's "Become a Mentor" / "Mentor Profile" entry point.
/// Reuses the existing mentorship infrastructure end to end — creating,
/// editing, viewing and pausing all go through the same `mentor_profiles`
/// row the Mentors listing/detail pages already read from.
class _MentorEntryCard extends ConsumerWidget {
  const _MentorEntryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentorAsync = ref.watch(myMentorProfileProvider);
    return mentorAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (mentor) {
        if (mentor == null) {
          return GradientBorderCard(
            radius: 20,
            gradient: LinearGradient(
              colors: [HomeStyle.violet.withValues(alpha: 0.28), HomeStyle.purple.withValues(alpha: 0.14)],
            ),
            onTap: () => context.push(RoutePaths.mentorProfileForm),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: HomeStyle.violet.withValues(alpha: 0.18)),
                    alignment: Alignment.center,
                    child: const Text('🎓', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Become a Mentor',
                            style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
                        SizedBox(height: 2),
                        Text('Share your expertise with the Communeo community',
                            style: TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: HomeStyle.textSecondary),
                ],
              ),
            ),
          );
        }

        final summary = mentor.expertise.take(3).join(' • ');
        return GradientBorderCard(
          radius: 20,
          gradient: LinearGradient(
            colors: [HomeStyle.violet.withValues(alpha: 0.28), HomeStyle.purple.withValues(alpha: 0.14)],
          ),
          onTap: () => _showMentorOptions(context, ref, mentor),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: HomeStyle.violet.withValues(alpha: 0.18)),
                  alignment: Alignment.center,
                  child: const Text('🎓', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mentor Profile',
                          style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      if (summary.isNotEmpty)
                        Text(summary,
                            style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(mentor.available ? '🟢' : '⚪', style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 5),
                          Text(mentor.available ? 'Accepting mentees' : 'Not accepting mentees',
                              style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: HomeStyle.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMentorOptions(BuildContext context, WidgetRef ref, Mentor mentor) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: HomeStyle.textPrimary),
              title: const Text('Edit Mentorship', style: TextStyle(color: HomeStyle.textPrimary)),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined, color: HomeStyle.textPrimary),
              title: const Text('View Mentor Profile', style: TextStyle(color: HomeStyle.textPrimary)),
              onTap: () => Navigator.of(context).pop('view'),
            ),
            ListTile(
              leading: Icon(mentor.available ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  color: HomeStyle.textPrimary),
              title: Text(mentor.available ? 'Pause Mentorship' : 'Resume Mentorship',
                  style: const TextStyle(color: HomeStyle.textPrimary)),
              onTap: () => Navigator.of(context).pop('toggle'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'edit':
        context.push(RoutePaths.mentorProfileForm);
      case 'view':
        context.push(RoutePaths.mentorDetailOf(mentor.profileId));
      case 'toggle':
        final ok = await ref
            .read(mentorControllerProvider.notifier)
            .becomeMentor({'available': !mentor.available});
        if (context.mounted) {
          context.showSnack(
            ok
                ? (mentor.available ? 'Mentorship paused' : 'Mentorship resumed')
                : 'Could not update mentorship status',
            isError: !ok,
          );
        }
    }
  }
}

/// The Profile page's "My Intents" entry point — reuses the existing
/// `intents`/`intent_skills` infrastructure end to end (My Intents screen,
/// Create/Edit Intent, Intent Detail) rather than a parallel summary here.
class _IntentEntryCard extends ConsumerWidget {
  const _IntentEntryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intentsAsync = ref.watch(myIntentsProvider);
    final activeCount = intentsAsync.valueOrNull?.where((i) => !i.isExpired && !i.isFulfilled).length ?? 0;

    return GradientBorderCard(
      radius: 20,
      gradient: LinearGradient(
        colors: [HomeStyle.cyan.withValues(alpha: 0.24), HomeStyle.purple.withValues(alpha: 0.12)],
      ),
      onTap: () => context.push(RoutePaths.myIntents),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: HomeStyle.cyan.withValues(alpha: 0.18)),
              alignment: Alignment.center,
              child: const Text('🎯', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Intents',
                      style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(
                    activeCount > 0 ? '$activeCount active intent${activeCount == 1 ? '' : 's'}' : 'Declare what you want to accomplish',
                    style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: HomeStyle.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.child,
    this.onEdit,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final Widget child;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GradientBorderCard(
        radius: 20,
        gradient: LinearGradient(colors: [accent.withValues(alpha: 0.24), HomeStyle.purple.withValues(alpha: 0.08)]),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.16),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
                  ),
                  if (onEdit != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: HomeStyle.purple.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 14, color: HomeStyle.purple),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12.5, color: HomeStyle.textSecondary, fontWeight: FontWeight.w500)),
    );
  }
}

class _AddPill extends StatelessWidget {
  const _AddPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: HomeStyle.cyan.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 14, color: HomeStyle.cyan),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12.5, color: HomeStyle.cyan, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _proofIcon(ProofType type) => switch (type) {
      ProofType.github => Icons.code_rounded,
      ProofType.leetcode => Icons.functions_rounded,
      ProofType.kaggle => Icons.bar_chart_rounded,
      ProofType.huggingface => Icons.smart_toy_outlined,
      ProofType.portfolio => Icons.language_rounded,
      ProofType.certification => Icons.verified_outlined,
      ProofType.project => Icons.folder_outlined,
    };

class _ProofOfSkillsSection extends ConsumerWidget {
  const _ProofOfSkillsSection({required this.isOwnProfile});

  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isOwnProfile) return const SizedBox.shrink();
    final proofsAsync = ref.watch(myOptionalProofsProvider);

    return _SectionCard(
      icon: Icons.workspace_premium_outlined,
      accent: HomeStyle.violet,
      title: 'Proof of Skills',
      child: proofsAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const Text('Could not load', style: TextStyle(color: HomeStyle.textSecondary)),
        data: (proofs) {
          if (proofs.isEmpty) {
            return Row(
              children: [
                const Expanded(
                  child: Text(
                    'Connect your GitHub, LeetCode, Kaggle and more to showcase your skills.',
                    style: TextStyle(fontSize: 12.5, color: HomeStyle.textSecondary, height: 1.4),
                  ),
                ),
                const SizedBox(width: 10),
                _ConnectButton(onTap: () => _openAddProof(context)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in proofs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(_proofIcon(p.proofType), size: 16, color: HomeStyle.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.title?.isNotEmpty == true ? p.title! : p.proofType.label,
                          style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: HomeStyle.textSecondary),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            ref.read(profileControllerProvider.notifier).deleteOptionalProof(p.id),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: _ConnectButton(label: 'Add another', onTap: () => _openAddProof(context)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddProof(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddProofSheet(),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.onTap, this.label = 'Connect'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: HomeStyle.violet.withValues(alpha: 0.6)),
          ),
          child: Text(label,
              style: const TextStyle(color: HomeStyle.violet, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ),
      ),
    );
  }
}

class _PostsList extends ConsumerWidget {
  const _PostsList({required this.profileId, required this.isOwnProfile});

  final String profileId;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(authorPostsProvider(profileId));
    return postsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const Text('Could not load posts', style: TextStyle(color: HomeStyle.textSecondary)),
      data: (posts) {
        if (posts.isEmpty) {
          return Text(
            isOwnProfile ? 'You haven\'t posted anything yet.' : 'No posts yet.',
            style: const TextStyle(color: HomeStyle.textSecondary),
          );
        }
        return Column(
          children: [
            for (final post in posts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PostCard(post: post),
              ),
          ],
        );
      },
    );
  }
}
