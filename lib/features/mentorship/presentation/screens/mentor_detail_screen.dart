import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../providers/mentor_providers.dart';

class MentorDetailScreen extends ConsumerWidget {
  const MentorDetailScreen({super.key, required this.mentorId});

  final String mentorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentorAsync = ref.watch(mentorDetailProvider(mentorId));
    final isLoading = ref.watch(mentorControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Mentor')),
      body: mentorAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (m) => ResponsiveCenter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(
                        avatarUrl: m.avatarUrl,
                        name: m.fullName ?? '?',
                        radius: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.fullName ?? 'Mentor',
                              style: context.textStyles.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          if (m.currentRole != null)
                            Text(m.currentRole!,
                                style: context.textStyles.bodyMedium?.copyWith(
                                    color: context.colors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (m.bio != null) ...[
                  Text(m.bio!),
                  const SizedBox(height: 16)
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                        label:
                            Text('${m.sessionDurationMinutes} min sessions')),
                    Chip(
                        label: Text(m.pricingType == 'free'
                            ? 'Free'
                            : '${m.price ?? ''} ${m.currency ?? ''}')),
                    for (final t in m.topics) Chip(label: Text(t)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Request mentorship'),
                    onPressed: isLoading
                        ? null
                        : () async {
                            final success = await ref
                                .read(mentorControllerProvider.notifier)
                                .requestMentorship(mentorId);
                            if (success && context.mounted)
                              context.showSnack('Request sent');
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
