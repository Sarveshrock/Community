import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../moderation/presentation/widgets/report_dialog.dart';
import '../providers/event_providers.dart';
import '../widgets/event_detail_view.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  Future<void> _handlePrimaryAction(
    BuildContext context,
    WidgetRef ref,
    EventActionState state,
  ) async {
    final controller = ref.read(eventControllerProvider.notifier);
    if (state == EventActionState.registered) {
      final ok = await controller.cancelRsvp(eventId);
      if (context.mounted && !ok) context.showSnack('Could not cancel', isError: true);
      return;
    }
    final result = await controller.joinEvent(eventId);
    if (!context.mounted) return;
    if (result == 'registered') {
      context.showSnack('You\'re registered!');
    } else if (result == 'requested') {
      context.showSnack('Request sent — the host will review it.');
    } else {
      final error = ref.read(eventControllerProvider).error;
      context.showSnack(error?.toString() ?? 'Could not join this event', isError: true);
    }
  }

  Future<void> _cancelEvent(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel this event?',
      message: 'Everyone registered will be notified. This can\'t be undone.',
      confirmLabel: 'Cancel event',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref.read(eventControllerProvider.notifier).cancelEvent(eventId);
    if (context.mounted) {
      context.showSnack(ok ? 'Event cancelled' : 'Could not cancel event', isError: !ok);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final attendingAsync = ref.watch(isAttendingEventProvider(eventId));
    final joinRequestAsync = ref.watch(myEventJoinRequestProvider(eventId));
    final agendaAsync = ref.watch(eventAgendaProvider(eventId));
    final speakersAsync = ref.watch(eventSpeakersProvider(eventId));
    final isActionLoading = ref.watch(eventControllerProvider).isLoading;
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: eventAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (event) {
          final isHost = event.hostId == myId;
          final state = resolveEventActionState(
            event: event,
            myId: myId,
            isAttending: attendingAsync.valueOrNull ?? false,
            myJoinRequestStatus: joinRequestAsync.valueOrNull?.status,
          );

          return SafeArea(
            child: Stack(
              children: [
                EventDetailView(
                  event: event,
                  agenda: agendaAsync.valueOrNull ?? const [],
                  speakers: speakersAsync.valueOrNull ?? const [],
                  actionState: state,
                  isActionLoading: isActionLoading,
                  onPrimaryAction: () => _handlePrimaryAction(context, ref, state),
                  organizerControls: isHost
                      ? _OrganizerControls(
                          eventId: eventId,
                          event: event,
                          onCancelEvent: () => _cancelEvent(context, ref),
                        )
                      : null,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                ),
                if (!isHost)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _RoundIconButton(
                      icon: Icons.flag_outlined,
                      onTap: () => showReportDialog(context,
                          targetType: ReportTargetType.event, targetId: eventId),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _OrganizerControls extends ConsumerWidget {
  const _OrganizerControls({required this.eventId, required this.event, required this.onCancelEvent});

  final String eventId;
  final CommunityEvent event;
  final VoidCallback onCancelEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingRequestsAsync =
        event.visibility == EventVisibility.inviteOnly ? ref.watch(eventJoinRequestsProvider(eventId)) : null;
    final pendingCount = pendingRequestsAsync?.valueOrNull?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: event.isCancelled
                    ? null
                    : () => context.push(RoutePaths.editEventOf(eventId)),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit event'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeStyle.purple,
                  side: BorderSide(color: HomeStyle.purple.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: event.isCancelled ? null : onCancelEvent,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel event'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFB7185),
                  side: const BorderSide(color: Color(0xFFFB7185)),
                ),
              ),
            ),
          ],
        ),
        if (pendingCount > 0) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showJoinRequests(context, ref),
            icon: const Icon(Icons.how_to_reg_outlined, size: 16),
            label: Text('$pendingCount pending request${pendingCount == 1 ? '' : 's'}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: HomeStyle.blue,
              side: BorderSide(color: HomeStyle.blue.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ],
    );
  }

  void _showJoinRequests(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeStyle.cardBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _JoinRequestsSheet(eventId: eventId),
    );
  }
}

class _JoinRequestsSheet extends ConsumerWidget {
  const _JoinRequestsSheet({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(eventJoinRequestsProvider(eventId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Join requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
            const SizedBox(height: 12),
            requestsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20), child: LinearProgressIndicator()),
              error: (_, __) => const Text('Could not load requests'),
              data: (requests) {
                if (requests.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No pending requests', style: TextStyle(color: HomeStyle.textSecondary)),
                  );
                }
                return Column(
                  children: [
                    for (final r in requests)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            UserAvatar(avatarUrl: r.requesterAvatarUrl, name: r.requesterName ?? '?', radius: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(r.requesterName ?? 'Community member',
                                  style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Color(0xFF22D98A)),
                              onPressed: () => ref
                                  .read(eventControllerProvider.notifier)
                                  .respondToJoinRequest(r.id, eventId, accept: true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFB7185)),
                              onPressed: () => ref
                                  .read(eventControllerProvider.notifier)
                                  .respondToJoinRequest(r.id, eventId, accept: false),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
