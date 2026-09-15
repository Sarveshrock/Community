import 'package:flutter/material.dart';

/// Visual language for the Sign In / Create Account screens only —
/// deliberately scoped here rather than folded into [AppTheme], the same
/// precedent `HomeStyle` set: the rest of the app keeps the user's actual
/// light/dark theme, while these two screens are a fixed "premium dark"
/// brand moment (like the reference), regardless of system theme.
class AuthStyle {
  AuthStyle._();

  // Background -----------------------------------------------------------
  static const Color backgroundTop = Color(0xFF050B1A);
  static const Color background = Color(0xFF020817);
  static const Color backgroundDeep = Color(0xFF071126);

  // Text -------------------------------------------------------------------
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFB8C4DD);
  static const Color textMuted = Color(0xFF7F8BA3);

  // Brand accents ----------------------------------------------------------
  static const Color blue = Color(0xFF2196FF);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color violet = Color(0xFF7C3AED);
  static const Color pink = Color(0xFFEC4899);

  // Surfaces -----------------------------------------------------------
  static const Color inputFill = Color(0xFF0B1730);
  static const Color cardFill = Color(0xD9081228); // rgba(8,18,40,0.85)
  static const Color border = Color(0x59508CFF); // rgba(80,140,255,0.35)
  static const Color borderFocused = Color(0xBF8B9CFF);
  static const Color borderError = Color(0xB2EC4899);

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [cyan, blue, purple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> glow(Color color,
      {double opacity = 0.28, double blur = 22, double spread = -4}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        spreadRadius: spread,
      ),
    ];
  }
}
