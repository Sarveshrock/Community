import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/startup_providers.dart';

class StartupsListScreen extends ConsumerWidget {
  const StartupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupsAsync = ref.watch(startupsListProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(onCreate: () => context.push(RoutePaths.newStartup)),
                  Expanded(
                    child: RefreshIndicator(
                      backgroundColor: HomeStyle.cardBase,
                      color: HomeStyle.purple,
                      onRefresh: () async =>
                          ref.invalidate(startupsListProvider),
                      child: startupsAsync.when(
                        loading: () => const SkeletonList(),
                        error: (e, _) => ErrorState(
                            message: e.toString(),
                            onRetry: () =>
                                ref.invalidate(startupsListProvider)),
                        data: (startups) {
                          if (startups.isEmpty) {
                            return const EmptyState(
                                icon: Icons.rocket_launch_outlined,
                                title: 'No startups yet',
                                message: 'Share yours and find co-founders.');
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: startups.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final s = startups[i];
                              return Material(
                                color: HomeStyle.cardBase,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => context.push(
                                      RoutePaths.startupDetailOf(s.id)),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.06)),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        UserAvatar(
                                            avatarUrl: s.logoUrl,
                                            name: s.name,
                                            radius: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(s.name,
                                                  style: const TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: HomeStyle
                                                          .textPrimary)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  [s.industry, s.stage]
                                                      .whereType<String>()
                                                      .join(' · '),
                                                  style: const TextStyle(
                                                      fontSize: 12.5,
                                                      color: HomeStyle
                                                          .textSecondary)),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded,
                                            color: HomeStyle.textSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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
          _IconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: () => context.pop()),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Startups',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          _IconButton(
              icon: Icons.add_rounded,
              tooltip: 'Share a startup',
              highlighted: true,
              onTap: onCreate),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.highlighted = false});

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
          border: highlighted
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}
