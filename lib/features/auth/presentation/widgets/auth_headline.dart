import 'package:flutter/material.dart';

import 'auth_style.dart';

/// The two-line page headline ("Welcome" / "back!", "Create your" /
/// "account"): a plain first line plus a gradient-masked second line.
/// Uses [ShaderMask] over the second line's own rendered bounds (the same
/// technique as `HomeStyle`'s `GradientText`) rather than a hand-picked
/// `Rect` size, so the gradient always covers exactly the rendered text no
/// matter how wide it turns out to be.
class AuthHeadline extends StatelessWidget {
  const AuthHeadline({super.key, required this.firstLine, required this.accentLine});

  final String firstLine;
  final String accentLine;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 29,
      fontWeight: FontWeight.w800,
      color: AuthStyle.textPrimary,
      height: 1.18,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(firstLine, style: style),
        ShaderMask(
          shaderCallback: (bounds) =>
              AuthStyle.brandGradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
          blendMode: BlendMode.srcIn,
          child: Text(accentLine, style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
