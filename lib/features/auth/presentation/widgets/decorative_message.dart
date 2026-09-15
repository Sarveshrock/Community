import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A short handwritten-style accent line (reference: "Same People. Bigger
/// Possibilities."). Uses `GoogleFonts.caveat` — already a dependency and
/// already this app's convention for this exact effect (see
/// `greeting_section.dart`/`inspiration_card.dart` on Home), so no new
/// font/package is introduced. Purely decorative: non-interactive, and
/// callers are responsible for placing it where it can't overlap the form.
class DecorativeMessage extends StatelessWidget {
  const DecorativeMessage(
    this.text, {
    super.key,
    this.fontSize = 17,
    this.color = Colors.white,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final double fontSize;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Text(
        text,
        textAlign: textAlign,
        style: GoogleFonts.caveat(
          fontSize: fontSize,
          height: 1.15,
          fontWeight: FontWeight.w600,
          color: color,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
        ),
      ),
    );
  }
}
