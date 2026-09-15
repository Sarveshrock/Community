import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../intents/presentation/providers/intent_providers.dart';
import 'home_style.dart';

/// The Home page's primary CTA. Opens the existing Intent flow — My Intents
/// when the user already has live ones, otherwise straight to creation.
class IntentHeroCard extends ConsumerWidget {
  const IntentHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = (ref.watch(myIntentsProvider).valueOrNull ?? const [])
        .where((i) => i.isEffectivelyActive)
        .length;

    return GradientBorderCard(
      gradient: HomeStyle.brandGradient,
      radius: 16,
      glowColor: HomeStyle.purple,
      borderWidth: 1.2,
      fill: const Color(0xFF141634),
      onTap: () => context.push(
          activeCount > 0 ? RoutePaths.myIntents : RoutePaths.newIntent),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF12233F), Color(0xFF241A45)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            const Icon(Icons.outlined_flag_rounded,
                size: 26, color: HomeStyle.textPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'What are you looking to accomplish?',
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: HomeStyle.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Declare an intent and let Communeo find the right people',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      color: HomeStyle.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  if (activeCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$activeCount active',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB98BFF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 24, color: HomeStyle.textPrimary),
          ],
        ),
      ),
    );
  }
}
