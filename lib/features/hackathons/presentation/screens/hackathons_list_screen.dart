import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../providers/hackathon_providers.dart';

class HackathonsListScreen extends ConsumerWidget {
  const HackathonsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hackathonsAsync = ref.watch(hackathonsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find a Team')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.newTeamRequirementStandalone),
        icon: const Icon(Icons.add),
        label: const Text('Post a team'),
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(hackathonsListProvider),
          child: hackathonsAsync.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(hackathonsListProvider)),
            data: (hackathons) {
              if (hackathons.isEmpty) {
                return const EmptyState(
                  icon: Icons.bolt_outlined,
                  title: 'No hackathons posted yet',
                  message:
                      'Registering for a hackathon and need teammates? Post it.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: hackathons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final h = hackathons[i];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () =>
                          context.push(RoutePaths.hackathonDetailOf(h.id)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.name,
                                style: context.textStyles.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            if (h.eventDate != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                DateFormat.yMMMd().format(h.eventDate!),
                                style: context.textStyles.bodySmall?.copyWith(
                                    color: context.colors.onSurfaceVariant),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.groups_2_outlined,
                                    size: 16,
                                    color: context.colors.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                    '${h.teamRequirementCount} teams looking for members',
                                    style: context.textStyles.bodySmall),
                              ],
                            ),
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
