import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../messaging/presentation/providers/message_providers.dart';
import '../providers/interview_practice_providers.dart';

/// Tabs mirror the two directions a pairing can start from: requests I sent
/// out and requests other pool members sent to me.
class MyInterviewPracticeRequestsScreen extends StatelessWidget {
  const MyInterviewPracticeRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Practice Requests'),
          bottom: const TabBar(tabs: [Tab(text: 'Sent'), Tab(text: 'Received')]),
        ),
        body: const ResponsiveCenter(
          child: TabBarView(children: [
            _RequestsList(mode: _Mode.sent),
            _RequestsList(mode: _Mode.received),
          ]),
        ),
      ),
    );
  }
}

enum _Mode { sent, received }

class _RequestsList extends ConsumerWidget {
  const _RequestsList({required this.mode});

  final _Mode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mode == _Mode.sent
        ? sentInterviewPracticeRequestsProvider
        : receivedInterviewPracticeRequestsProvider;
    final requestsAsync = ref.watch(provider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(provider),
      child: requestsAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) =>
            ErrorState(message: e.toString(), onRetry: () => ref.invalidate(provider)),
        data: (requests) {
          if (requests.isEmpty) {
            return EmptyState(
              icon: Icons.record_voice_over_outlined,
              title: mode == _Mode.sent
                  ? 'No practice requests sent yet'
                  : 'No practice requests received yet',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _RequestCard(request: requests[i], mode: mode),
          );
        },
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.mode});

  final InterviewPracticeRequest request;
  final _Mode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(interviewPracticeControllerProvider.notifier);
    final isLoading = ref.watch(interviewPracticeControllerProvider).isLoading;
    final otherId = mode == _Mode.sent ? request.partnerId : request.requesterId;
    final otherName = mode == _Mode.sent ? request.partnerName : request.requesterName;
    final otherAvatar =
        mode == _Mode.sent ? request.partnerAvatarUrl : request.requesterAvatarUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserAvatar(avatarUrl: otherAvatar, name: otherName ?? '?'),
              title: Text(otherName ?? 'Community member'),
              subtitle: Text(request.targetRole),
              trailing: Chip(
                  label: Text(request.status.label),
                  visualDensity: VisualDensity.compact),
            ),
            if (request.message != null) ...[
              const SizedBox(height: 4),
              Text(request.message!),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (mode == _Mode.received &&
                    request.status == InterviewPracticeStatus.pending) ...[
                  FilledButton(
                    onPressed: isLoading
                        ? null
                        : () => controller.respondToRequest(request.id, accept: true),
                    child: const Text('Accept'),
                  ),
                  OutlinedButton(
                    onPressed: isLoading
                        ? null
                        : () => controller.respondToRequest(request.id, accept: false),
                    child: const Text('Decline'),
                  ),
                ],
                if (request.status == InterviewPracticeStatus.accepted) ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Open chat'),
                    onPressed: () async {
                      final conversationId =
                          await ref.read(directConversationIdProvider(otherId).future);
                      if (context.mounted) {
                        context.push(RoutePaths.chatOf(conversationId));
                      }
                    },
                  ),
                  OutlinedButton(
                    onPressed:
                        isLoading ? null : () => controller.markCompleted(request.id),
                    child: const Text('Mark completed'),
                  ),
                ],
                if ({InterviewPracticeStatus.pending, InterviewPracticeStatus.accepted}
                    .contains(request.status))
                  TextButton(
                    onPressed: isLoading ? null : () => controller.cancelRequest(request.id),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
