import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../hackathons/presentation/providers/hackathon_providers.dart';
import '../../../interview_practice/presentation/providers/interview_practice_providers.dart';
import '../../../referrals/presentation/providers/referral_providers.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_providers.dart';

const _iconByType = {
  'message': Icons.chat_bubble_outline,
  'connection_request': Icons.person_add_alt_1_outlined,
  'connection_accepted': Icons.person_add_alt_1,
  'team_invitation': Icons.groups_2_outlined,
  'team_invitation_accepted': Icons.celebration_outlined,
  'team_invitation_declined': Icons.groups_2_outlined,
  'team_join_request': Icons.groups_2_outlined,
  'team_join_request_accepted': Icons.celebration_outlined,
  'team_join_request_rejected': Icons.groups_2_outlined,
  'team_member_left': Icons.person_remove_outlined,
  'team_deleted': Icons.groups_2_outlined,
  'project_interest': Icons.handyman_outlined,
  'job': Icons.work_outline,
  'mentor_request': Icons.school_outlined,
  'local_connection_request': Icons.near_me_outlined,
  'meetup_suggestion': Icons.event_available_outlined,
  'meetup_accepted': Icons.celebration_outlined,
  'news': Icons.newspaper_outlined,
  'community_event': Icons.event_outlined,
  'post_mention': Icons.alternate_email,
  'referral_requested': Icons.badge_outlined,
  'referral_accepted': Icons.badge,
  'referral_declined': Icons.badge_outlined,
  'referral_resume_submitted': Icons.description_outlined,
  'referral_submitted': Icons.send_outlined,
  'referral_outcome_updated': Icons.celebration_outlined,
  'referral_cancelled': Icons.badge_outlined,
  'interview_practice_requested': Icons.record_voice_over_outlined,
  'interview_practice_accepted': Icons.record_voice_over,
  'interview_practice_declined': Icons.record_voice_over_outlined,
  'interview_practice_cancelled': Icons.record_voice_over_outlined,
};

/// Notification types with inline Accept/Reject actions (spec section 6).
/// Everything else is informational-only.
const _actionableTypes = {
  'team_invitation',
  'team_join_request',
  'referral_requested',
  'interview_practice_requested',
};

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Locally hides actions on a notification the user has already acted on
  // in this session — the underlying invitation/request status changed,
  // but the notification row itself doesn't, so this is tracked here
  // rather than re-derived from it.
  final Set<String> _handledIds = {};
  final Set<String> _respondingIds = {};

  Future<void> _respond(AppNotification n, {required bool accept}) async {
    setState(() => _respondingIds.add(n.id));
    final hackathonId = n.data['hackathon_id'] as String?;
    final requestId = n.data['request_id'] as String?;
    bool ok;
    switch (n.type) {
      case 'team_invitation':
        final invitationId = n.data['invitation_id'] as String?;
        ok = invitationId != null &&
            await ref
                .read(hackathonControllerProvider.notifier)
                .respondToInvitation(
                  invitationId,
                  accept: accept,
                  hackathonId: hackathonId,
                );
        break;
      case 'referral_requested':
        final offerId = n.data['offer_id'] as String?;
        ok = requestId != null &&
            offerId != null &&
            await ref
                .read(referralControllerProvider.notifier)
                .respondToRequest(requestId, offerId, accept: accept);
        break;
      case 'interview_practice_requested':
        ok = requestId != null &&
            await ref
                .read(interviewPracticeControllerProvider.notifier)
                .respondToRequest(requestId, accept: accept);
        break;
      default:
        ok = requestId != null &&
            await ref
                .read(hackathonControllerProvider.notifier)
                .respondToJoinRequest(
                  requestId,
                  accept: accept,
                  hackathonId: hackathonId,
                );
    }
    if (!mounted) return;
    setState(() {
      _respondingIds.remove(n.id);
      if (ok) _handledIds.add(n.id);
    });
    context.showSnack(
      ok
          ? (accept ? 'Accepted' : 'Declined')
          : 'Could not respond — it may have already been handled',
      isError: !ok,
    );
    if (!n.isRead)
      ref.read(notificationControllerProvider.notifier).markRead(n.id);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ResponsiveCenter(
        child: notificationsAsync.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ErrorState(
              message: e.toString(),
              onRetry: () => ref.invalidate(myNotificationsProvider)),
          data: (notifications) {
            if (notifications.isEmpty) {
              return const EmptyState(
                  icon: Icons.notifications_none,
                  title: 'You\'re all caught up');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final n = notifications[i];
                final showActions = _actionableTypes.contains(n.type) &&
                    !_handledIds.contains(n.id);
                final isResponding = _respondingIds.contains(n.id);

                return Material(
                  color: n.isRead
                      ? Colors.transparent
                      : context.colors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (!n.isRead) {
                        ref
                            .read(notificationControllerProvider.notifier)
                            .markRead(n.id);
                      }
                      final postId = n.data['post_id'] as String?;
                      final offerId = n.data['offer_id'] as String?;
                      if (postId != null) {
                        context.push(RoutePaths.postDetailOf(postId));
                      } else if (n.type.startsWith('referral_') && offerId != null) {
                        context.push(RoutePaths.referralOfferDetailOf(offerId));
                      } else if (n.type.startsWith('interview_practice_')) {
                        context.push(RoutePaths.myInterviewPracticeRequests);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                              child: Icon(_iconByType[n.type] ??
                                  Icons.notifications_outlined)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n.title,
                                        style: TextStyle(
                                            fontWeight: n.isRead
                                                ? FontWeight.normal
                                                : FontWeight.w700),
                                      ),
                                    ),
                                    Text(
                                        timeago.format(n.createdAt,
                                            locale: 'en_short'),
                                        style: context.textStyles.bodySmall),
                                  ],
                                ),
                                if (n.body != null) ...[
                                  const SizedBox(height: 2),
                                  Text(n.body!,
                                      style: context.textStyles.bodyMedium),
                                ],
                                if (showActions) ...[
                                  const SizedBox(height: 10),
                                  if (isResponding)
                                    const SizedBox(
                                      height: 32,
                                      width: 32,
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  else
                                    Row(
                                      children: [
                                        FilledButton(
                                          onPressed: () =>
                                              _respond(n, accept: true),
                                          child: const Text('Accept'),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: () =>
                                              _respond(n, accept: false),
                                          child: const Text('Reject'),
                                        ),
                                      ],
                                    ),
                                ],
                              ],
                            ),
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
    );
  }
}
