import 'package:flutter/material.dart';

/// Home-page visual language (dark navy + per-feature accent glows).
///
/// Deliberately scoped to the Home feature rather than pushed into
/// [AppTheme]: the rest of the app keeps the standard Material surface
/// colours, so these tokens only apply where the redesigned page uses them.
class HomeStyle {
  HomeStyle._();

  // Page ---------------------------------------------------------------
  static const Color background = Color(0xFF070912);
  static const Color cardBase = Color(0xFF0E1120);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA3AECB);
  static const Color divider = Color(0x1AFFFFFF);

  // Brand accents ------------------------------------------------------
  static const Color blue = Color(0xFF4C8DFF);
  static const Color purple = Color(0xFF9D5CFF);
  static const Color pink = Color(0xFFEC4899);
  static const Color green = Color(0xFF10D9A0);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color cyan = Color(0xFF22D3EE);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Soft accent glow. Kept to a single low-opacity shadow per element —
  /// layered blurs are what make this kind of UI janky on real phones.
  static List<BoxShadow> glow(Color color, {double opacity = 0.22, double blur = 18}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        spreadRadius: -2,
      ),
    ];
  }
}

/// A card with a 1px accent gradient border over a dark fill — the shape the
/// intent hero and every action card share.
class GradientBorderCard extends StatelessWidget {
  const GradientBorderCard({
    super.key,
    required this.child,
    required this.gradient,
    this.radius = 18,
    this.fill,
    this.glowColor,
    this.borderWidth = 1,
    this.onTap,
  });

  final Widget child;
  final Gradient gradient;
  final double radius;
  final Color? fill;
  final Color? glowColor;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient,
        boxShadow: glowColor == null ? null : HomeStyle.glow(glowColor!),
      ),
      child: Padding(
        padding: EdgeInsets.all(borderWidth),
        child: Material(
          color: fill ?? HomeStyle.cardBase,
          borderRadius: BorderRadius.circular(radius - borderWidth),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: child),
        ),
      ),
    );
  }
}

/// Applies a gradient to text via [ShaderMask] (used for the user's name in
/// the greeting).
class GradientText extends StatelessWidget {
  const GradientText(this.text,
      {super.key, required this.style, this.gradient = HomeStyle.brandGradient});

  final String text;
  final TextStyle style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

/// The small pill labels under each action card's description.
class HomeChip extends StatelessWidget {
  const HomeChip(this.label, {super.key, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          height: 1.1,
          color: Color(0xFFD7DEF0),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Two soft radial washes behind a page — the shared premium-dark atmosphere
/// used by Home and any other screen adopting the same visual language
/// (e.g. Buddies). Plain gradients, no [BackdropFilter]: decorative, so it
/// shouldn't cost a full-screen blur pass every frame.
class GlowBackdrop extends StatelessWidget {
  const GlowBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -100,
            child: _Glow(color: HomeStyle.blue, size: 320, opacity: 0.16),
          ),
          Positioned(
            top: -60,
            right: -110,
            child: _Glow(color: HomeStyle.purple, size: 300, opacity: 0.16),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow(
      {required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Small circular chevron affordance in the corner of each action card.
class HomeCardArrow extends StatelessWidget {
  const HomeCardArrow({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.chevron_right_rounded,
        size: 16, color: color ?? HomeStyle.textSecondary);
  }
}
