import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../profile/presentation/providers/profile_providers.dart';
import 'home_style.dart';

/// "Hi <name>," with the name gradient-filled, plus the handwritten
/// "Same People. Bigger Possibilities." mark.
///
/// The script line is dropped on very narrow screens rather than squeezed —
/// it's decorative, and the greeting is what has to stay readable.
class GreetingSection extends ConsumerWidget {
  const GreetingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName =
        ref.watch(myProfileProvider).valueOrNull?.fullName?.split(' ').first;
    final width = MediaQuery.sizeOf(context).width;
    // Only shown where it doesn't squeeze the greeting into extra lines.
    final showScript = width >= 380;
    final titleSize = width < 360 ? 32.0 : 38.0;

    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Hi ',
              style: TextStyle(
                fontSize: titleSize,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: HomeStyle.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Flexible(
              child: GradientText(
                '${firstName ?? 'there'},',
                style: TextStyle(
                  fontSize: titleSize,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'What do you want to do today?',
          style: TextStyle(
            fontSize: width < 360 ? 15 : 17,
            height: 1.2,
            color: HomeStyle.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );

    if (!showScript) return greeting;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: greeting),
        const SizedBox(width: 8),
        const _ScriptTagline(),
      ],
    );
  }
}

class _ScriptTagline extends StatelessWidget {
  const _ScriptTagline();

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.caveat(
      fontSize: 17,
      height: 1.1,
      fontWeight: FontWeight.w600,
      color: const Color(0xFFB98BFF),
    );

    return Transform.rotate(
      angle: -0.04,
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Same People.', style: style, textAlign: TextAlign.right),
            Text('Bigger', style: style, textAlign: TextAlign.right),
            Text('Possibilities.', style: style, textAlign: TextAlign.right),
            const SizedBox(height: 2),
            Container(
              height: 2,
              width: 86,
              decoration: BoxDecoration(
                gradient: HomeStyle.brandGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
