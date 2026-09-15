import 'package:flutter/material.dart';

import 'auth_style.dart';

/// One Google/Apple button — dark glass card, real brand mark, minimum
/// 48px touch target. [onPressed] is passed straight through to the
/// caller's existing `signInWithGoogle()`/`signInWithApple()` call; this
/// widget has no auth logic of its own.
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuthStyle.inputFill.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AuthStyle.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AuthStyle.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The multi-color Google "G" — painted rather than pulled from a package,
/// since this project has no SVG asset pipeline (checked `pubspec.yaml`).
class GoogleLogoMark extends StatelessWidget {
  const GoogleLogoMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.22;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    const twoPi = 6.28318530718;
    const gapDeg = 3.0; // small gaps between arcs, in degrees
    const gap = gapDeg * twoPi / 360;

    // Angles measured clockwise from 3 o'clock (standard canvas convention).
    paint.color = const Color(0xFFEA4335); // red: top
    canvas.drawArc(rect, _deg(-90) + gap / 2, _deg(90) - gap, false, paint);
    paint.color = const Color(0xFF4285F4); // blue: right
    canvas.drawArc(rect, _deg(0) + gap / 2, _deg(90) - gap, false, paint);
    paint.color = const Color(0xFF34A853); // green: bottom
    canvas.drawArc(rect, _deg(90) + gap / 2, _deg(90) - gap, false, paint);
    paint.color = const Color(0xFFFBBC05); // yellow: left
    canvas.drawArc(rect, _deg(180) + gap / 2, _deg(90) - gap, false, paint);

    // The crossbar: a short blue rectangle from center-right toward center,
    // the detail that makes the ring read as a "G" rather than a donut.
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    final barHeight = strokeWidth * 0.92;
    final bar = Rect.fromLTWH(
      center.dx - size.width * 0.02,
      center.dy - barHeight / 2,
      radius - strokeWidth / 2 + size.width * 0.02,
      barHeight,
    );
    canvas.drawRect(bar, barPaint);
  }

  double _deg(double degrees) => degrees * 6.28318530718 / 360;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
