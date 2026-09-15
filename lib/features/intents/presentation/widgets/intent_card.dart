import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/models/skill.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/intent.dart';
import '../../domain/intent_config.dart';

/// Compact card for the discovery list, My Intents and Profile — type,
/// title, short description, top skills needed/offered, experience,
/// location/remote, commitment, status and expiry.
class IntentCard extends StatelessWidget {
  const IntentCard({super.key, required this.intent, required this.onTap});

  final UserIntent intent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final config = intentTypeConfig(intent.intentType);
    final topNeeded = intent.skillsNeeded.take(2).toList();
    final topOffered = intent.skillsOffered.take(2).toList();

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(gradient: HomeStyle.brandGradient, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Icon(config.icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(intent.intentType.label,
                            style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(intent.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      ],
                    ),
                  ),
                  _StatusChip(label: intent.statusLabel),
                ],
              ),
              if ((intent.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(intent.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5, height: 1.4)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Badge(intent.experienceLevel.label),
                  if ((intent.workMode ?? '').isNotEmpty) _Badge(intent.workMode!),
                  if ((intent.locationPreference ?? '').isNotEmpty) _Badge(intent.locationPreference!),
                  if ((intent.commitmentLevel ?? '').isNotEmpty) _Badge(intent.commitmentLevel!),
                ],
              ),
              if (topNeeded.isNotEmpty || topOffered.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in topNeeded) _SkillChip(label: s, accent: HomeStyle.purple, prefix: 'Need'),
                    for (final s in topOffered) _SkillChip(label: s, accent: HomeStyle.cyan, prefix: 'Offer'),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!intent.isExpired && !intent.isFulfilled)
                    Text('Expires in ${intent.daysUntilExpiry}d',
                        style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11)),
                  const Spacer(),
                  Text(timeago.format(intent.createdAt.toLocal()),
                      style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final (emoji, color) = switch (label) {
      'Fulfilled' => ('✅', HomeStyle.purple),
      'Expiring Soon' => ('🟡', const Color(0xFFE0A83E)),
      'Expired' => ('🔴', const Color(0xFFE05B5B)),
      'Cancelled' => ('🔴', const Color(0xFFE05B5B)),
      'Paused' => ('⏸', HomeStyle.textSecondary),
      _ => ('🟢', const Color(0xFF3ECF8E)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(100)),
      child: Text('$emoji $label', style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
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

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, required this.accent, required this.prefix});
  final String label;
  final Color accent;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(100)),
      child: Text('$prefix: $label', style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
    );
  }
}
