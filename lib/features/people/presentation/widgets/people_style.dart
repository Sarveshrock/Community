import 'package:flutter/material.dart';

/// Visual language for the People screen only — same scoping precedent as
/// `HomeStyle`/`AuthStyle`: kept local rather than folded into `AppTheme`
/// so the rest of the app is unaffected. Hex values match the redesign
/// brief's own palette exactly.
class PeopleStyle {
  PeopleStyle._();

  static const Color background = Color(0xFF020817);
  static const Color surface = Color(0xFF071126);
  static const Color card = Color(0xFF0B1328);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFB8C4DD);
  static const Color textMuted = Color(0xFF7F8BA3);

  static const Color blue = Color(0xFF2196FF);
  static const Color cyan = Color(0xFF00C2FF);
  static const Color purple = Color(0xFF7C3AED);
  static const Color brightPurple = Color(0xFFA855F7);
  static const Color pink = Color(0xFFEC4899);

  static const Color online = Color(0xFF00D084);
  static const Color offline = Color(0xFF64748B);

  static const Color border = Color(0x59508CFF); // blue/purple, ~35% alpha

  static const LinearGradient selectedChipGradient = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient recommendedGradient = LinearGradient(
    colors: [purple, pink],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Deterministic per-profile ring color — same idea as Buddies' accent
  /// assignment, so a person's card always renders the same accent.
  static const List<Color> avatarRing = [blue, purple, pink, online, brightPurple, cyan];

  static Color ringFor(String id) => avatarRing[id.hashCode.abs() % avatarRing.length];

  static List<BoxShadow> glow(Color color, {double opacity = 0.24, double blur = 18}) {
    return [
      BoxShadow(color: color.withValues(alpha: opacity), blurRadius: blur, spreadRadius: -3),
    ];
  }
}
