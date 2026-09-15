import 'package:flutter/material.dart';

/// Brand palette. Deliberately not a LinkedIn-style corporate blue (spec
/// section 67): a warmer indigo/teal system that reads as premium and
/// community-oriented rather than "professional networking app #482".
class AppColors {
  AppColors._();

  static const Color seed = Color(0xFF4F46E5); // indigo
  static const Color accent = Color(0xFF14B8A6); // teal
  static const Color localAccent =
      Color(0xFFF97316); // warm orange, sets Local apart

  static const Color lightBackground = Color(0xFFFAFAFC);
  static const Color darkBackground = Color(0xFF121218);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
}
