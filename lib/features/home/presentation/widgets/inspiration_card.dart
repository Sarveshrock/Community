import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_style.dart';

/// "Today's Inspiration". The scenery is painted with [CustomPainter] rather
/// than shipped as a bitmap: no asset to bundle, nothing fetched at runtime,
/// and it stays sharp at every density.
class InspirationCard extends StatelessWidget {
  const InspirationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sized from the card's own width, not the screen's — the card sits
        // inside page padding, so the two aren't the same.
        final cardWidth = constraints.maxWidth;
        final tight = cardWidth < 330;
        final sceneLeft = cardWidth * (tight ? 0.46 : 0.50);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141A33),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: tight ? 156 : 148,
            child: Stack(
              children: [
                Positioned(
                  left: sceneLeft,
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: const _MountainScene(),
                ),
                // Feathers the scene's left edge into the card.
                Positioned(
                  left: sceneLeft - 26,
                  top: 0,
                  bottom: 0,
                  width: 60,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF141A33), Color(0x00141A33)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Both this and the quote below used to have no
                      // shrink/ellipsis path — safe at the width this was
                      // eyeballed against, but the quote's box narrows with
                      // the card (sceneLeft shrinks on narrow phones), and
                      // actually rendering at 320px showed it wrapping past
                      // the card's fixed height.
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wb_sunny_outlined,
                              size: 16, color: HomeStyle.amber),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Today\'s Inspiration',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: HomeStyle.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: sceneLeft - 18,
                        child: const Text(
                          '"The right people can turn your goals into reality."',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.32,
                            fontStyle: FontStyle.italic,
                            color: HomeStyle.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 2,
                        width: 64,
                        decoration: BoxDecoration(
                          gradient: HomeStyle.brandGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  right: 10,
                  top: 11,
                  child: _ScriptWords(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScriptWords extends StatelessWidget {
  const _ScriptWords();

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.caveat(
      fontSize: 16,
      height: 1.15,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
    );
    return SizedBox(
      width: 66,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Build', style: style, maxLines: 1),
          Text('Learn', style: style, maxLines: 1),
          Text('Connect', style: style, maxLines: 1),
          Text('Grow', style: style, maxLines: 1),
          const SizedBox(height: 3),
          Container(
            height: 2,
            width: 46,
            decoration: BoxDecoration(
              gradient: HomeStyle.brandGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _MountainScene extends StatelessWidget {
  const _MountainScene();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MountainPainter(), isComplex: true);
  }
}

/// Dusk sky, low sun and three ridgelines. Plain gradients and filled paths —
/// no blur filters, so it costs almost nothing to raster.
class _MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Sky: deep violet overhead warming to amber at the horizon.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF232459),
            Color(0xFF4B3172),
            Color(0xFFA4557A),
            Color(0xFFE8925A),
          ],
          stops: [0.0, 0.32, 0.58, 0.80],
        ).createShader(rect),
    );

    // Sun and halo, sitting just above the ridge.
    final sun = Offset(w * 0.44, h * 0.72);
    canvas.drawCircle(
      sun,
      h * 0.34,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE1AE).withValues(alpha: 0.75),
            const Color(0xFFFFB169).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: h * 0.34)),
    );
    canvas.drawCircle(sun, h * 0.06, Paint()..color = const Color(0xFFFFF3D6));

    void ridge(List<Offset> pts, Color color) {
      final path = Path()..moveTo(0, h);
      path.lineTo(0, pts.first.dy);
      for (final p in pts) {
        path.lineTo(p.dx, p.dy);
      }
      path.lineTo(w, h);
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    // Back to front, each darker than the last for depth.
    ridge([
      Offset(w * 0.10, h * 0.58),
      Offset(w * 0.26, h * 0.72),
      Offset(w * 0.42, h * 0.56),
      Offset(w * 0.58, h * 0.70),
      Offset(w * 0.76, h * 0.50),
      Offset(w, h * 0.66),
    ], const Color(0xFF6A4F7E));

    ridge([
      Offset(w * 0.14, h * 0.78),
      Offset(w * 0.34, h * 0.62),
      Offset(w * 0.52, h * 0.80),
      Offset(w * 0.70, h * 0.60),
      Offset(w, h * 0.78),
    ], const Color(0xFF3E3059));

    ridge([
      Offset(w * 0.08, h * 0.93),
      Offset(w * 0.30, h * 0.84),
      Offset(w * 0.50, h * 0.96),
      Offset(w * 0.72, h * 0.82),
      Offset(w, h * 0.92),
    ], const Color(0xFF1E1836));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
