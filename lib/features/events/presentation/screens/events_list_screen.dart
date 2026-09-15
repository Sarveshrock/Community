import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/event_providers.dart';
import '../widgets/event_card.dart';

class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsListProvider);
    final filters = ref.watch(eventFiltersProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(onCreate: () => context.push(RoutePaths.newEvent)),
                  _FiltersRow(filters: filters),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => ref.invalidate(eventsListProvider),
                      child: eventsAsync.when(
                        loading: () => const SkeletonList(),
                        error: (e, _) => ErrorState(
                            message: e.toString(), onRetry: () => ref.invalidate(eventsListProvider)),
                        data: (events) {
                          if (events.isEmpty) {
                            return EmptyState(
                              icon: Icons.event_outlined,
                              title: filters.upcomingOnly ? 'No upcoming events' : 'No past events',
                              message: 'Organize a workshop, talk, or meetup.',
                              actionLabel: filters.upcomingOnly ? 'Create event' : null,
                              onAction: filters.upcomingOnly ? () => context.push(RoutePaths.newEvent) : null,
                            );
                          }
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 1,
                              mainAxisExtent: 260,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: events.length,
                            itemBuilder: (context, i) => EventCard(event: events[i]),
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
            child: Text('Events',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: HomeStyle.textPrimary)),
          ),
          _IconButton(icon: Icons.add_rounded, tooltip: 'Create event', highlighted: true, onTap: onCreate),
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

  final EventFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(eventFiltersProvider.notifier);
    final chips = <(String, bool, VoidCallback)>[
      ('Upcoming', filters.upcomingOnly, () => notifier.state = filters.copyWith(upcomingOnly: true)),
      ('Past', !filters.upcomingOnly, () => notifier.state = filters.copyWith(upcomingOnly: false)),
      ('Free only', filters.freeOnly, () => notifier.state = filters.copyWith(freeOnly: !filters.freeOnly)),
      ('Online', filters.mode == 'online',
          () => notifier.state = filters.copyWith(mode: filters.mode == 'online' ? null : 'online')),
      ('Offline', filters.mode == 'offline',
          () => notifier.state = filters.copyWith(mode: filters.mode == 'offline' ? null : 'offline')),
    ];
    return SizedBox(
      height: 44,
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected ? HomeStyle.brandGradient : null,
                  color: selected ? null : HomeStyle.cardBase.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(100),
                  border: selected ? null : Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
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
