import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import 'auth_style.dart';

/// The three-node "people" mark, in the app's blue/purple brand gradient.
/// No bundled logo asset exists in this project (checked `pubspec.yaml`'s
/// `assets:` list and `assets/`), so this is a small, lightweight painted
/// mark rather than a fake raster logo.
class CommuneoLogoMark extends StatelessWidget {
  const CommuneoLogoMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final nodeSize = size * 0.44;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: _Node(size: nodeSize, colors: const [AuthStyle.cyan, AuthStyle.blue]),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: _Node(size: nodeSize, colors: const [AuthStyle.blue, AuthStyle.purple]),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _Node(size: nodeSize, colors: const [AuthStyle.purple, AuthStyle.pink]),
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AuthStyle.glow(colors.first, opacity: 0.35, blur: 14, spread: -3),
      ),
    );
  }
}

/// Logo mark + "Communeo" wordmark + "PEOPLE × PURPOSE × PROGRESS" tagline,
/// centered — the header both auth screens share.
class CommuneoBrandHeader extends StatelessWidget {
  const CommuneoBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CommuneoLogoMark(size: 60),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) =>
              AuthStyle.brandGradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
          blendMode: BlendMode.srcIn,
          child: const Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'PEOPLE  ×  PURPOSE  ×  PROGRESS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: AuthStyle.textMuted,
          ),
        ),
      ],
    );
  }
}
