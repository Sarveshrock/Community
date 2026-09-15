import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/community_providers.dart';
import '../widgets/community_card.dart';

class CommunitiesListScreen extends ConsumerWidget {
  const CommunitiesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communitiesAsync = ref.watch(communitiesListProvider);
    final filters = ref.watch(communityFiltersProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(onCreate: () => context.push(RoutePaths.newCommunity)),
                  _FiltersRow(filters: filters),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => ref.invalidate(communitiesListProvider),
                      child: communitiesAsync.when(
                        loading: () => const SkeletonList(),
                        error: (e, _) =>
                            ErrorState(message: e.toString(), onRetry: () => ref.invalidate(communitiesListProvider)),
                        data: (communities) {
                          if (communities.isEmpty) {
                            return EmptyState(
                              icon: Icons.groups_outlined,
                              title: 'No communities yet',
                              message: 'Start one around a shared interest.',
                              actionLabel: 'New community',
                              onAction: () => context.push(RoutePaths.newCommunity),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: communities.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, i) => CommunityCard(
                              community: communities[i],
                              onTap: () => context.push(RoutePaths.communityDetailOf(communities[i].id)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _IconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.pop()),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Communities', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: HomeStyle.textPrimary)),
          ),
          _IconButton(icon: Icons.add_rounded, tooltip: 'New community', highlighted: true, onTap: onCreate),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tooltip, required this.onTap, this.highlighted = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: highlighted ? HomeStyle.brandGradient : null,
          color: highlighted ? null : HomeStyle.cardBase,
          borderRadius: BorderRadius.circular(13),
          border: highlighted ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(borderRadius: BorderRadius.circular(13), onTap: onTap, child: Icon(icon, color: Colors.white, size: 21)),
        ),
      ),
    );
  }
}

class _FiltersRow extends ConsumerWidget {
  const _FiltersRow({required this.filters});
  final CommunityFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(communityFiltersProvider.notifier);
    final chips = <(String, bool, VoidCallback)>[
      ('All types', filters.communityType == null, () => notifier.state = filters.copyWith(communityType: null)),
      for (final t in kCommunityTypes)
        (
          communityTypeLabel(t),
          filters.communityType == t,
          () => notifier.state = filters.copyWith(communityType: filters.communityType == t ? null : t),
        ),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, selected, onTap) = chips[i];
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected ? HomeStyle.brandGradient : null,
                  color: selected ? null : HomeStyle.cardBase.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(100),
                  border: selected ? null : Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : HomeStyle.textSecondary)),
              ),
            ),
          );
        },
      ),
    );
  }
}
