import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/project_providers.dart';

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsListProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(onCreate: () => context.push(RoutePaths.newProject)),
                  Expanded(
                    child: RefreshIndicator(
                      backgroundColor: HomeStyle.cardBase,
                      color: HomeStyle.purple,
                      onRefresh: () async =>
                          ref.invalidate(projectsListProvider),
                      child: projectsAsync.when(
                        loading: () => const SkeletonList(),
                        error: (e, _) => ErrorState(
                            message: e.toString(),
                            onRetry: () =>
                                ref.invalidate(projectsListProvider)),
                        data: (projects) {
                          if (projects.isEmpty) {
                            return const EmptyState(
                              icon: Icons.handyman_outlined,
                              title: 'No open projects',
                              message: 'Post one to find collaborators.',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: projects.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final p = projects[i];
                              return GradientBorderCard(
                                radius: 18,
                                gradient: LinearGradient(
                                  colors: [
                                    HomeStyle.violet.withValues(alpha: 0.28),
                                    HomeStyle.violet.withValues(alpha: 0.06),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () => context
                                    .push(RoutePaths.projectDetailOf(p.id)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.title,
                                          style: const TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w700,
                                              color: HomeStyle.textPrimary)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          HomeChip(p.collaborationType.label,
                                              accent: HomeStyle.violet),
                                          HomeChip(p.compensationType.label,
                                              accent: HomeStyle.green),
                                        ],
                                      ),
                                      if (p.description != null) ...[
                                        const SizedBox(height: 10),
                                        Text(p.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                height: 1.35,
                                                color:
                                                    HomeStyle.textSecondary)),
                                      ],
                                      if (p.requiredSkillNames
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            for (final s in p
                                                .requiredSkillNames
                                                .take(4))
                                              HomeChip(s,
                                                  accent: HomeStyle.blue),
                                          ],
                                        ),
                                      ],
                                    ],
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
            child: Text('Projects',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          _IconButton(
              icon: Icons.add_rounded,
              tooltip: 'Post a project',
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
