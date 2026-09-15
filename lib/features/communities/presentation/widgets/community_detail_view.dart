import 'package:flutter/material.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/community_action.dart';
import '../../domain/entities/community.dart';

/// The community's static/informational rendering — shared by the real,
/// provider-backed `CommunityDetailScreen` and the Community Builder's live
/// Preview step. Every optional section is conditionally rendered only
/// when the community actually has that data — an old community (posted
/// before 0047_community_rich_details.sql) with only name/description/type
/// renders exactly as it always did, with every new section simply absent.
///
/// Dynamic, provider-backed sections (discussions, pre-join Q&A, members,
/// events, chat entry) don't exist yet at preview time, so they're passed
/// in as [trailingSections] by the real screen only — this widget never
/// fetches anything itself.
class CommunityDetailView extends StatelessWidget {
  const CommunityDetailView({
    super.key,
    required this.community,
    this.logoBytesPreview,
    this.coverBytesPreview,
    this.actionState,
    this.onPrimaryAction,
    this.isActionLoading = false,
    this.organizerControls,
    this.trailingSections = const [],
  });

  final Community community;
  final ImageProvider? logoBytesPreview;
  final ImageProvider? coverBytesPreview;

  /// Null in preview mode — shows a static "Preview" badge instead of a
  /// real CTA.
  final CommunityAction? actionState;
  final VoidCallback? onPrimaryAction;
  final bool isActionLoading;
  final Widget? organizerControls;
  final List<Widget> trailingSections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _Header(community: community, logoOverride: logoBytesPreview, coverOverride: coverBytesPreview),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrimaryActionRow(actionState: actionState, onPrimaryAction: onPrimaryAction, isLoading: isActionLoading),
              const SizedBox(height: 18),
              if ((community.description ?? '').isNotEmpty) ...[
                const _SectionHeader('About'),
                Text(community.description!, style: const TextStyle(color: HomeStyle.textSecondary, height: 1.5)),
                const SizedBox(height: 20),
              ],
              if (community.activities.isNotEmpty) ...[
                const _SectionHeader('What happens here?'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in community.activities)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: Text('${communityActivityEmoji(a)} $a',
                            style: const TextStyle(fontSize: 12.5, color: HomeStyle.textPrimary, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (community.topicNames.isNotEmpty) ...[
                const _SectionHeader('Topics'),
                _ChipWrap(items: community.topicNames, accent: HomeStyle.purple),
                const SizedBox(height: 20),
              ],
              if (community.audience.isNotEmpty) ...[
                const _SectionHeader('Who is this for?'),
                _ChipWrap(items: community.audience, accent: HomeStyle.cyan),
                const SizedBox(height: 20),
              ],
              if ((community.rules ?? '').isNotEmpty) ...[
                const _SectionHeader('Community rules'),
                Text(community.rules!, style: const TextStyle(color: HomeStyle.textSecondary, height: 1.6)),
                const SizedBox(height: 20),
              ],
              ...trailingSections,
              if (organizerControls != null) ...[
                const SizedBox(height: 20),
                organizerControls!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.community, this.logoOverride, this.coverOverride});
  final Community community;
  final ImageProvider? logoOverride;
  final ImageProvider? coverOverride;

  @override
  Widget build(BuildContext context) {
    final cover = coverOverride ?? (community.coverImageUrl != null ? NetworkImage(community.coverImageUrl!) : null);
    final logo = logoOverride ?? (community.logoUrl != null ? NetworkImage(community.logoUrl!) : null);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 130,
          decoration: BoxDecoration(
            gradient: cover == null ? HomeStyle.brandGradient : null,
            image: cover != null ? DecorationImage(image: cover, fit: BoxFit.cover) : null,
          ),
        ),
        Positioned(
          left: 16,
          bottom: -28,
          child: Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: HomeStyle.background),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: logo == null ? HomeStyle.brandGradient : null,
                image: logo != null ? DecorationImage(image: logo, fit: BoxFit.cover) : null,
              ),
              alignment: Alignment.center,
              child: logo == null
                  ? Text(community.name.isEmpty ? '?' : community.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22))
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 138, left: 16, right: 16, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(community.name,
                  style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
              if ((community.tagline ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(community.tagline!, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 13.5)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaBadge('${community.memberCount} member${community.memberCount == 1 ? '' : 's'}'),
                  _MetaBadge(communityTypeLabel(community.communityType)),
                  _MetaBadge(communityAccessTypeLabel(community.accessType)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11.5, color: HomeStyle.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}

class _PrimaryActionRow extends StatelessWidget {
  const _PrimaryActionRow({required this.actionState, required this.onPrimaryAction, required this.isLoading});

  final CommunityAction? actionState;
  final VoidCallback? onPrimaryAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (actionState == null) {
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
    if (actionState == CommunityAction.owner ||
        actionState == CommunityAction.member ||
        actionState == CommunityAction.none) {
      return const SizedBox.shrink();
    }

    final state = actionState!;
    final enabled = state.isActionable && !isLoading;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: enabled ? onPrimaryAction : null,
          child: Container(
            decoration: BoxDecoration(
              gradient: enabled ? HomeStyle.brandGradient : null,
              color: enabled ? null : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(100),
              boxShadow: enabled ? HomeStyle.glow(HomeStyle.purple, opacity: 0.3) : null,
            ),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(state.label,
                    style: TextStyle(
                        color: enabled ? Colors.white : HomeStyle.textSecondary, fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
        ),
      ),
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

/// Small reusable avatar for member/asker rows used by the trailing
/// sections the real detail screen appends (discussions, Q&A).
class CommunityPersonAvatar extends StatelessWidget {
  const CommunityPersonAvatar({super.key, required this.name, this.avatarUrl, this.radius = 16});
  final String name;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) => UserAvatar(avatarUrl: avatarUrl, name: name, radius: radius);
}
