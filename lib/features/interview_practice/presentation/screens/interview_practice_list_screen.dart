import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/skill.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../providers/interview_practice_providers.dart';

/// Browse the mock-interview practice pool (spec-extension: Mock Interview
/// Matching). Setting up your own listing is a profile toggle, not postable
/// content, so — like Mentors — it isn't in the Create menu; it lives here.
class InterviewPracticeListScreen extends ConsumerWidget {
  const InterviewPracticeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolAsync = ref.watch(interviewPracticePoolProvider);
    final myProfileAsync = ref.watch(myInterviewPracticeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock Interviews'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'My requests',
            onPressed: () => context.push(RoutePaths.myInterviewPracticeRequests),
          ),
        ],
      ),
      floatingActionButton: myProfileAsync.maybeWhen(
        data: (profile) => FloatingActionButton.extended(
          onPressed: () => context.push(RoutePaths.editInterviewPracticeProfile),
          icon: Icon(profile == null ? Icons.add : Icons.edit_outlined),
          label: Text(profile == null ? 'Join the pool' : 'Edit my profile'),
        ),
        orElse: () => null,
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(interviewPracticePoolProvider),
          child: poolAsync.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(interviewPracticePoolProvider)),
            data: (pool) {
              if (pool.isEmpty) {
                return const EmptyState(
                  icon: Icons.record_voice_over_outlined,
                  title: 'No one in the practice pool yet',
                  message: 'Join the pool to find a mock-interview partner.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: pool.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = pool[i];
                  return Card(
                    child: ListTile(
                      onTap: () => context.push(
                          RoutePaths.interviewPracticePartnerDetailOf(p.profileId)),
                      leading: UserAvatar(
                          avatarUrl: p.avatarUrl, name: p.fullName ?? '?', radius: 24),
                      title: Text(p.fullName ?? 'Community member',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(p.topics.isNotEmpty
                          ? '${p.targetRole} · ${p.topics.join(', ')}'
                          : p.targetRole),
                      trailing: Chip(
                          label: Text(p.experienceLevel.label),
                          visualDensity: VisualDensity.compact),
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
