import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_style.dart';

/// The shared backdrop behind both auth screens: a deep navy gradient, two
/// soft blue/purple glow orbs, and a subtle abstract horizon silhouette at
/// the bottom — all drawn/painted rather than a bundled image, so it costs
/// nothing to load and never clips oddly on unusual screen sizes.
/// [IgnorePointer]-wrapped throughout: purely decorative, never intercepts
/// taps meant for the form above it.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AuthStyle.backgroundTop,
                  AuthStyle.background,
                  AuthStyle.backgroundDeep,
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -90,
            left: -80,
            child: _Orb(color: AuthStyle.blue, size: 280, opacity: 0.20),
          ),
          Positioned(
            top: -40,
            right: -100,
            child: _Orb(color: AuthStyle.purple, size: 300, opacity: 0.18),
          ),
          Positioned(
            bottom: 140,
            right: -60,
            child: _Orb(color: AuthStyle.pink, size: 180, opacity: 0.10),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _HorizonPainter(height: 190),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size, required this.opacity});

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
          colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// A very low-opacity mountain ridge + glowing horizon line, echoing the
/// reference's bottom illustration without a bitmap asset.
class _HorizonPainter extends StatelessWidget {
  const _HorizonPainter({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _RidgePainter()),
    );
  }
}

class _RidgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft glow hugging the horizon line.
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AuthStyle.purple.withValues(alpha: 0.16),
          AuthStyle.purple.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.62, h * 0.42), radius: w * 0.55));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);

    final ridge = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.62)
      ..lineTo(w * 0.14, h * 0.50)
      ..lineTo(w * 0.24, h * 0.58)
      ..lineTo(w * 0.38, h * 0.36)
      ..lineTo(w * 0.5, h * 0.50)
      ..lineTo(w * 0.66, h * 0.30)
      ..lineTo(w * 0.80, h * 0.48)
      ..lineTo(w * 0.92, h * 0.40)
      ..lineTo(w, h * 0.52)
      ..lineTo(w, h)
      ..close();

    final ridgePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AuthStyle.backgroundDeep.withValues(alpha: 0.0),
          AuthStyle.backgroundDeep.withValues(alpha: 0.85),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(ridge, ridgePaint);

    // A thin glowing horizon line just above the ridge crest.
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = LinearGradient(colors: [
        AuthStyle.blue.withValues(alpha: 0.0),
        AuthStyle.purple.withValues(alpha: 0.55),
        AuthStyle.pink.withValues(alpha: 0.0),
      ]).createShader(Rect.fromLTWH(0, 0, w, h));
    final line = Path()..moveTo(0, h * 0.5);
    for (double x = 0; x <= w; x += w / 40) {
      final y = h * 0.46 + math.sin(x / w * math.pi) * (h * 0.05);
      line.lineTo(x, y);
    }
    canvas.drawPath(line, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
