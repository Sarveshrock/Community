import 'package:flutter/material.dart';

import '../../../../core/models/skill.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/intent.dart';
import '../../domain/intent_config.dart';

/// The Intent's full rendering — shared by the real, provider-backed
/// `IntentDetailScreen` and the Create/Edit flow's Preview step, so the two
/// can never visually drift apart.
///
/// The dynamic section is driven entirely by [intentTypeConfig] — this
/// widget never branches on [IntentType] itself, so a new intent type added
/// there automatically renders here with no changes to this file. Any
/// section without data (including every intent posted before
/// 0048_intent_structured_details.sql, which has no metadata at all) is
/// simply omitted — never a blank space, never a literal "null".
class IntentDetailView extends StatelessWidget {
  const IntentDetailView({
    super.key,
    required this.intent,
    this.actions,
    this.ownerControls,
    this.shrinkWrap = false,
    this.physics,
  });

  final UserIntent intent;

  /// Connect/Message row — null in preview mode.
  final Widget? actions;

  /// Edit / Mark fulfilled / Pause / Delete — shown only to the owner.
  final Widget? ownerControls;

  /// Set true (with [physics] = [NeverScrollableScrollPhysics]) to embed this
  /// inline inside another scrollable — e.g. the Create Intent screen's live
  /// preview section — instead of using it as a whole screen's body.
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final config = intentTypeConfig(intent.intentType);
    final dynamicEntries = [
      for (final field in config.fields)
        if (_hasValue(intent.metadata[field.key])) (field, intent.metadata[field.key]),
    ];

    return ListView(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: const EdgeInsets.all(16),
      children: [
        _Header(intent: intent, config: config),
        const SizedBox(height: 18),
        if (actions != null) ...[actions!, const SizedBox(height: 18)],
        _QuickInfoGrid(intent: intent),
        const SizedBox(height: 20),
        if ((intent.description ?? '').isNotEmpty) ...[
          const _SectionHeader('Description'),
          Text(intent.description!, style: const TextStyle(color: HomeStyle.textSecondary, height: 1.5)),
          const SizedBox(height: 20),
        ],
        if (intent.skillsNeeded.isNotEmpty) ...[
          const _SectionHeader('What I need'),
          _ChipWrap(items: intent.skillsNeeded, accent: HomeStyle.purple),
          const SizedBox(height: 20),
        ],
        if (intent.skillsOffered.isNotEmpty) ...[
          const _SectionHeader('What I can offer'),
          _ChipWrap(items: intent.skillsOffered, accent: HomeStyle.cyan),
          const SizedBox(height: 20),
        ],
        if (dynamicEntries.isNotEmpty) ...[
          _SectionHeader(config.sectionTitle),
          _DynamicFieldsBlock(entries: dynamicEntries),
          const SizedBox(height: 20),
        ],
        if (intent.fullName != null) ...[
          const _SectionHeader('Posted by'),
          _PosterCard(intent: intent),
          const SizedBox(height: 20),
        ],
        if (ownerControls != null) ownerControls!,
      ],
    );
  }

  static bool _hasValue(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.isNotEmpty;
    return true;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.intent, required this.config});

  final UserIntent intent;
  final IntentConfiguration config;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: HomeStyle.brandGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(config.icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                intent.intentType.label,
                style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            _StatusBadge(intent: intent),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          intent.title,
          style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 21, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.intent});

  final UserIntent intent;

  @override
  Widget build(BuildContext context) {
    final label = intent.statusLabel;
    final (emoji, color) = switch (label) {
      'Fulfilled' => ('✅', HomeStyle.purple),
      'Expiring Soon' => ('🟡', const Color(0xFFE0A83E)),
      'Expired' => ('🔴', const Color(0xFFE05B5B)),
      'Cancelled' => ('🔴', const Color(0xFFE05B5B)),
      'Paused' => ('⏸', HomeStyle.textSecondary),
      _ => ('🟢', const Color(0xFF3ECF8E)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text('$emoji $label', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _QuickInfoGrid extends StatelessWidget {
  const _QuickInfoGrid({required this.intent});

  final UserIntent intent;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.trending_up_rounded, intent.experienceLevel.label),
      if ((intent.preferredRole ?? '').isNotEmpty) (Icons.badge_outlined, intent.preferredRole!),
      if ((intent.locationPreference ?? '').isNotEmpty) (Icons.place_outlined, intent.locationPreference!),
      if ((intent.workMode ?? '').isNotEmpty) (Icons.wifi_outlined, intent.workMode!),
      if ((intent.commitmentLevel ?? '').isNotEmpty) (Icons.schedule_outlined, intent.commitmentLevel!),
      if (!intent.isExpired && !intent.isFulfilled)
        (Icons.hourglass_bottom_outlined, 'Expires in ${intent.daysUntilExpiry}d'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (icon, label) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: HomeStyle.textSecondary),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 12.5)),
              ],
            ),
          ),
      ],
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
      child: Text(title, style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
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
            child: Text(item, style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _DynamicFieldsBlock extends StatelessWidget {
  const _DynamicFieldsBlock({required this.entries});

  final List<(IntentFieldSpec, dynamic)> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (field, value) in entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                if (value is List)
                  _ChipWrap(items: value.map((e) => e.toString()).toList(), accent: HomeStyle.purple)
                else
                  Text(value.toString(), style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.intent});
  final UserIntent intent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(avatarUrl: intent.avatarUrl, name: intent.fullName ?? '?', radius: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(intent.fullName!, style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700)),
              if ((intent.currentRole ?? '').isNotEmpty)
                Text(intent.currentRole!, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }
}
