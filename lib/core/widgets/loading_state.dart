import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Skeleton loader for card-based lists (spec section 67).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6, this.itemHeight = 96});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surfaceContainerLow;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
