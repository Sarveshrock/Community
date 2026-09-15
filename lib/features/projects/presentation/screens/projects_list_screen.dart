import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../providers/project_providers.dart';

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RoutePaths.newProject),
        child: const Icon(Icons.add),
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(projectsListProvider),
          child: projectsAsync.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(projectsListProvider)),
            data: (projects) {
              if (projects.isEmpty) {
                return const EmptyState(
                  icon: Icons.handyman_outlined,
                  title: 'No open projects',
                  message: 'Post one to find collaborators.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: projects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final p = projects[i];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () =>
                          context.push(RoutePaths.projectDetailOf(p.id)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title,
                                style: context.textStyles.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Chip(
                                    label: Text(p.collaborationType.label),
                                    visualDensity: VisualDensity.compact),
                                const SizedBox(width: 6),
                                Chip(
                                    label: Text(p.compensationType.label),
                                    visualDensity: VisualDensity.compact),
                              ],
                            ),
                            if (p.description != null) ...[
                              const SizedBox(height: 8),
                              Text(p.description!,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                            if (p.requiredSkillNames.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                children: [
                                  for (final s in p.requiredSkillNames.take(4))
                                    Chip(
                                        label: Text(s),
                                        visualDensity: VisualDensity.compact)
                                ],
                              ),
                            ],
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
    );
  }
}
