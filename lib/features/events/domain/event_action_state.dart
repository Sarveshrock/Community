import 'entities/event.dart';
import 'entities/event_join_request.dart';

/// What the event detail page's primary CTA should show for the current
/// viewer — purely a function of event + viewer state, mirroring
/// `resolveTeamCardAction` (hackathons feature)'s precedent so the UI never
/// has to guess or duplicate this logic per screen.
enum EventActionState {
  /// Not signed in — nothing actionable.
  none,

  /// The viewer is hosting this event: organizer controls instead of a
  /// join CTA.
  host,

  cancelled,
  ended,

  /// Already registered/accepted.
  registered,

  /// Invite-only, and the viewer's request is awaiting the host.
  pendingApproval,

  /// Started but not ended, and the viewer isn't in it — joining a live
  /// event that isn't a casual drop-in doesn't make sense.
  inProgress,

  full,
  registrationClosed,

  /// Invite-only, no request sent yet.
  requestToJoin,

  /// Nothing blocking — show "Join Event"/"Register".
  join,
}

EventActionState resolveEventActionState({
  required CommunityEvent event,
  required String? myId,
  required bool isAttending,
  EventJoinRequestStatus? myJoinRequestStatus,
}) {
  if (myId == null) return EventActionState.none;
  if (event.hostId == myId) return EventActionState.host;
  if (event.isCancelled) return EventActionState.cancelled;
  if (event.hasEnded) return EventActionState.ended;
  if (isAttending) return EventActionState.registered;
  if (myJoinRequestStatus == EventJoinRequestStatus.pending) {
    return EventActionState.pendingApproval;
  }
  if (event.hasStarted) return EventActionState.inProgress;
  if (event.isFull) return EventActionState.full;
  if (event.registrationClosed) return EventActionState.registrationClosed;
  if (event.visibility == EventVisibility.inviteOnly) {
    return EventActionState.requestToJoin;
  }
  return EventActionState.join;
}

extension EventActionStateLabel on EventActionState {
  String get label => switch (this) {
        EventActionState.none => '',
        EventActionState.host => '',
        EventActionState.cancelled => 'Event cancelled',
        EventActionState.ended => 'Event ended',
        EventActionState.registered => 'Registered',
        EventActionState.pendingApproval => 'Pending approval',
        EventActionState.inProgress => 'Event in progress',
        EventActionState.full => 'Event full',
        EventActionState.registrationClosed => 'Registration closed',
        EventActionState.requestToJoin => 'Request to join',
        EventActionState.join => 'Join event',
      };

  /// Whether the primary CTA is tappable at all.
  bool get isActionable =>
      this == EventActionState.join || this == EventActionState.requestToJoin;
}
