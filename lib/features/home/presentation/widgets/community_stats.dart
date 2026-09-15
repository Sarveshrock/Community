import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_providers.dart';
import 'home_style.dart';

/// Community totals row. Scrolls horizontally rather than compressing, so
/// four stats plus dividers never overflow a 320px screen.
class CommunityStatsRow extends ConsumerWidget {
  const CommunityStatsRow({super.key, required this.horizontalPadding});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(communityStatsProvider);

    final items = stats.maybeWhen(
      data: (s) => [
        (Icons.people_outline_rounded, _format(s.people), 'People'),
        (Icons.explore_outlined, _format(s.projects), 'Projects'),
        (Icons.work_outline_rounded, _format(s.opportunities), 'Opportunities'),
        (Icons.groups_2_outlined, _format(s.communities), 'Communities'),
      ],
      orElse: () => [
        (Icons.people_outline_rounded, '—', 'People'),
        (Icons.explore_outlined, '—', 'Projects'),
        (Icons.work_outline_rounded, '—', 'Opportunities'),
        (Icons.groups_2_outlined, '—', 'Communities'),
      ],
    );

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: items.length,
        separatorBuilder: (_, __) => Container(
          width: 1,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: HomeStyle.divider,
        ),
        itemBuilder: (context, i) {
          final (icon, value, label) = items[i];
          return _Stat(icon: icon, value: value, label: label);
        },
      ),
    );
  }

  /// 1200 -> "1.2K+", 980 -> "980". Rounds down so the figure is never an
  /// overstatement of what's actually in the database.
  static String _format(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      final text = k >= 10 ? k.floor().toString() : k.toStringAsFixed(1);
      return '${text.replaceAll(RegExp(r'\.0$'), '')}K+';
    }
    return n.toString();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: HomeStyle.textSecondary),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: HomeStyle.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.1,
                color: HomeStyle.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
