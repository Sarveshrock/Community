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
import '../../../home/presentation/widgets/home_style.dart';
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

/// Deterministic accent per notification type — purely decorative, gives the
/// icon badges some variety instead of every row looking identical.
const _accentByType = {
  'message': HomeStyle.blue,
  'connection_request': HomeStyle.green,
  'connection_accepted': HomeStyle.green,
  'job': HomeStyle.amber,
  'news': HomeStyle.cyan,
  'referral_requested': HomeStyle.pink,
  'referral_accepted': HomeStyle.pink,
  'referral_declined': HomeStyle.pink,
  'interview_practice_requested': HomeStyle.cyan,
  'interview_practice_accepted': HomeStyle.cyan,
};

Color _accentFor(String type) => _accentByType[type] ?? HomeStyle.purple;

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
    if (!n.isRead) {
      ref.read(notificationControllerProvider.notifier).markRead(n.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(myNotificationsProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  const _Header(),
                  Expanded(
                    child: notificationsAsync.when(
                      loading: () => const SkeletonList(),
                      error: (e, _) => ErrorState(
                          message: e.toString(),
                          onRetry: () =>
                              ref.invalidate(myNotificationsProvider)),
                      data: (notifications) {
                        if (notifications.isEmpty) {
                          return const EmptyState(
                              icon: Icons.notifications_none,
                              title: 'You\'re all caught up',
                              message:
                                  'New activity on your connections, teams and requests shows up here.');
                        }
                        return RefreshIndicator(
                          backgroundColor: HomeStyle.cardBase,
                          color: HomeStyle.purple,
                          onRefresh: () async =>
                              ref.invalidate(myNotificationsProvider),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final n = notifications[i];
                              final showActions =
                                  _actionableTypes.contains(n.type) &&
                                      !_handledIds.contains(n.id);
                              final isResponding =
                                  _respondingIds.contains(n.id);
                              return _NotificationTile(
                                notification: n,
                                showActions: showActions,
                                isResponding: isResponding,
                                onTap: () {
                                  if (!n.isRead) {
                                    ref
                                        .read(notificationControllerProvider
                                            .notifier)
                                        .markRead(n.id);
                                  }
                                  final postId = n.data['post_id'] as String?;
                                  final offerId =
                                      n.data['offer_id'] as String?;
                                  final chatRoute = n.type == 'message'
                                      ? RoutePaths.chatRouteForMessageData(
                                          n.data)
                                      : null;
                                  if (chatRoute != null) {
                                    context.push(chatRoute);
                                  } else if (postId != null) {
                                    context
                                        .push(RoutePaths.postDetailOf(postId));
                                  } else if (n.type.startsWith('referral_') &&
                                      offerId != null) {
                                    context.push(
                                        RoutePaths.referralOfferDetailOf(
                                            offerId));
                                  } else if (n.type
                                      .startsWith('interview_practice_')) {
                                    context.push(
                                        RoutePaths.myInterviewPracticeRequests);
                                  }
                                },
                                onAccept: () => _respond(n, accept: true),
                                onReject: () => _respond(n, accept: false),
                              );
                            },
                          ),
                        );
                      },
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
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _IconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: HomeStyle.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: HomeStyle.cardBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 21, color: HomeStyle.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.showActions,
    required this.isResponding,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
  });

  final AppNotification notification;
  final bool showActions;
  final bool isResponding;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final accent = _accentFor(n.type);
    final unread = !n.isRead;

    return Material(
      color: unread
          ? accent.withValues(alpha: 0.08)
          : HomeStyle.cardBase.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.4)]),
                  boxShadow: HomeStyle.glow(accent, opacity: 0.3, blur: 10),
                ),
                child: Icon(_iconByType[n.type] ?? Icons.notifications_outlined,
                    size: 19, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                              color: HomeStyle.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(n.createdAt, locale: 'en_short'),
                          style: const TextStyle(
                              fontSize: 11, color: HomeStyle.textSecondary),
                        ),
                      ],
                    ),
                    if (n.body != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        n.body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: HomeStyle.textSecondary),
                      ),
                    ],
                    if (showActions) ...[
                      const SizedBox(height: 10),
                      if (isResponding)
                        const SizedBox(
                          height: 30,
                          width: 30,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: HomeStyle.purple),
                          ),
                        )
                      else
                        Row(
                          children: [
                            _GradientPillButton(
                                label: 'Accept', onTap: onAccept),
                            const SizedBox(width: 8),
                            _OutlinePillButton(
                                label: 'Reject', onTap: onReject),
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
  }
}

class _GradientPillButton extends StatelessWidget {
  const _GradientPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: HomeStyle.brandGradient,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    );
  }
}

class _OutlinePillButton extends StatelessWidget {
  const _OutlinePillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: HomeStyle.textSecondary)),
        ),
      ),
    );
  }
}
