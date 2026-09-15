import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connectivity_provider.dart';

/// Thin banner shown above screen content when connectivity drops (spec
/// section 70). Wrap any screen body with this to surface offline state
/// without every feature re-implementing the same check.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: isOnline
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Text(
                    'You\'re offline. Showing cached content where available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
