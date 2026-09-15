import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../providers/mentor_providers.dart';

class MentorsListScreen extends ConsumerWidget {
  const MentorsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentorsAsync = ref.watch(mentorsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mentors')),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(mentorsListProvider),
          child: mentorsAsync.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(mentorsListProvider)),
            data: (mentors) {
              if (mentors.isEmpty) {
                return const EmptyState(
                    icon: Icons.school_outlined,
                    title: 'No mentors available yet');
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: mentors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final m = mentors[i];
                  return Card(
                    child: ListTile(
                      onTap: () =>
                          context.push(RoutePaths.mentorDetailOf(m.profileId)),
                      leading: UserAvatar(
                          avatarUrl: m.avatarUrl,
                          name: m.fullName ?? '?',
                          radius: 24),
                      title: Text(m.fullName ?? 'Mentor',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(m.topics.isNotEmpty
                          ? m.topics.join(', ')
                          : (m.currentRole ?? '')),
                      trailing: Chip(
                          label:
                              Text(m.pricingType == 'free' ? 'Free' : 'Paid'),
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
