import 'package:flutter/material.dart';

/// Shows an AI match score as a soft recommendation, never as objective
/// truth (spec section 42): "92% recommended match", with the reason
/// available on tap rather than an unqualified number. Soft purple/pink
/// gradient with a subtle glow — only ever shown for AI-scored results
/// (callers pass a score exactly when one exists; never invented locally).
class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.score, this.reason});

  final double score;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF7C3AED);
    const pink = Color(0xFFEC4899);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [purple, pink]),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: -3),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '${score.round()}% match',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (reason == null) return badge;
    return Tooltip(message: reason!, child: badge);
  }
}
