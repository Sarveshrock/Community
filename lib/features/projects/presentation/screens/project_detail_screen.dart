import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../moderation/presentation/widgets/report_action_button.dart';
import '../providers/project_providers.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final interestedAsync = ref.watch(hasExpressedInterestProvider(projectId));
    final isLoading = ref.watch(projectControllerProvider).isLoading;
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project'),
        actions: [
          ReportActionButton(
              targetType: ReportTargetType.project, targetId: projectId)
        ],
      ),
      body: projectAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (p) {
          final isOwner = p.ownerId == myId;
          return ResponsiveCenter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      style: context.textStyles.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(label: Text(p.collaborationType.label)),
                      Chip(label: Text(p.compensationType.label)),
                      if (p.category != null) Chip(label: Text(p.category!)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (p.description != null) ...[
                    Text(p.description!),
                    const SizedBox(height: 16),
                  ],
                  if (p.durationDescription != null) ...[
                    Text('Duration',
                        style: context.textStyles.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(p.durationDescription!),
                    const SizedBox(height: 16),
                  ],
                  if (p.requiredSkillNames.isNotEmpty) ...[
                    Text('Skills needed',
                        style: context.textStyles.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in p.requiredSkillNames) Chip(label: Text(s))
                    ]),
                    const SizedBox(height: 16),
                  ],
                  if (!isOwner)
                    interestedAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (interested) => SizedBox(
                        width: double.infinity,
                        child: interested
                            ? const OutlinedButton(
                                onPressed: null, child: Text('Interest sent'))
                            : FilledButton.icon(
                                icon: const Icon(Icons.handshake_outlined),
                                label: const Text('I\'m interested'),
                                onPressed: isLoading
                                    ? null
                                    : () => ref
                                        .read(
                                            projectControllerProvider.notifier)
                                        .expressInterest(projectId, null),
                              ),
                      ),
                    ),
                  if (isOwner) ...[
                    const SizedBox(height: 8),
                    Text('Interested people',
                        style: context.textStyles.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Consumer(builder: (context, ref, _) {
                      final interestsAsync =
                          ref.watch(projectInterestsProvider(projectId));
                      return interestsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) =>
                            const Text('Could not load interests'),
                        data: (interests) {
                          if (interests.isEmpty)
                            return const Text(
                                'No one has expressed interest yet.');
                          return Column(
                            children: [
                              for (final interest in interests)
                                Card(
                                  child: ListTile(
                                    leading: UserAvatar(
                                      avatarUrl: interest['profiles']
                                          ?['avatar_url'] as String?,
                                      name: interest['profiles']?['full_name']
                                              as String? ??
                                          '?',
                                    ),
                                    title: Text(interest['profiles']
                                            ?['full_name'] as String? ??
                                        'Community member'),
                                    subtitle: Text(
                                        interest['status'] as String? ??
                                            'pending'),
                                    trailing: interest['status'] == 'pending'
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.check_circle,
                                                    color: Colors.green),
                                                onPressed: () => ref
                                                    .read(
                                                        projectControllerProvider
                                                            .notifier)
                                                    .respondToInterest(
                                                        projectId,
                                                        interest['id']
                                                            as String,
                                                        accept: true),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.cancel,
                                                    color:
                                                        context.colors.error),
                                                onPressed: () => ref
                                                    .read(
                                                        projectControllerProvider
                                                            .notifier)
                                                    .respondToInterest(
                                                        projectId,
                                                        interest['id']
                                                            as String,
                                                        accept: false),
                                              ),
                                            ],
                                          )
                                        : null,
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
