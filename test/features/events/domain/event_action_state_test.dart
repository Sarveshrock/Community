// Locks down resolveEventActionState — the single source of truth for what
// the event detail page's primary CTA shows, mirroring team_card_action_test
// (hackathons feature)'s precedent for this kind of pure state-resolution
// function.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/events/domain/entities/event.dart';
import 'package:community_app/features/events/domain/entities/event_join_request.dart';
import 'package:community_app/features/events/domain/event_action_state.dart';

CommunityEvent _event({
  String hostId = 'host-1',
  DateTime? startsAt,
  DateTime? endsAt,
  int? maxParticipants,
  int attendeeCount = 0,
  DateTime? registrationDeadline,
  EventVisibility visibility = EventVisibility.public,
  EventStatus status = EventStatus.published,
}) {
  return CommunityEvent(
    id: 'event-1',
    hostId: hostId,
    title: 'Test event',
    startsAt: startsAt ?? DateTime.now().add(const Duration(days: 7)),
    endsAt: endsAt,
    maxParticipants: maxParticipants,
    attendeeCount: attendeeCount,
    registrationDeadline: registrationDeadline,
    visibility: visibility,
    status: status,
  );
}

void main() {
  test('signed-out viewer sees none', () {
    expect(
      resolveEventActionState(event: _event(), myId: null, isAttending: false),
      EventActionState.none,
    );
  });

  test('the host sees host, never a join CTA', () {
    expect(
      resolveEventActionState(event: _event(hostId: 'me'), myId: 'me', isAttending: false),
      EventActionState.host,
    );
  });

  test('a cancelled event shows cancelled regardless of other state', () {
    final event = _event(status: EventStatus.cancelled, maxParticipants: 1, attendeeCount: 5);
    expect(
      resolveEventActionState(event: event, myId: 'me', isAttending: false),
      EventActionState.cancelled,
    );
  });

  test('an event that already ended shows ended, even if not full', () {
    final event = _event(
      startsAt: DateTime.now().subtract(const Duration(days: 2)),
      endsAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(
      resolveEventActionState(event: event, myId: 'me', isAttending: false),
      EventActionState.ended,
    );
  });

  test('an already-registered attendee sees registered', () {
    expect(
      resolveEventActionState(event: _event(), myId: 'me', isAttending: true),
      EventActionState.registered,
    );
  });

  test('a pending invite-only request shows pendingApproval, not requestToJoin', () {
    final event = _event(visibility: EventVisibility.inviteOnly);
    expect(
      resolveEventActionState(
        event: event,
        myId: 'me',
        isAttending: false,
        myJoinRequestStatus: EventJoinRequestStatus.pending,
      ),
      EventActionState.pendingApproval,
    );
  });

  test('a started-but-not-ended event the viewer isn\'t in shows inProgress', () {
    final event = _event(
      startsAt: DateTime.now().subtract(const Duration(hours: 1)),
      endsAt: DateTime.now().add(const Duration(hours: 1)),
    );
    expect(
      resolveEventActionState(event: event, myId: 'me', isAttending: false),
      EventActionState.inProgress,
    );
  });

  test('a full event (before it starts) shows full', () {
    final event = _event(maxParticipants: 2, attendeeCount: 2);
    expect(
      resolveEventActionState(event: event, myId: 'me', isAttending: false),
      EventActionState.full,
    );
  });

  test('a passed registration deadline shows registrationClosed, even with room left', () {
    final event = _event(
      maxParticipants: 100,
      attendeeCount: 1,
      registrationDeadline: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(
      resolveEventActionState(event: event, myId: 'me', isAttending: false),
      EventActionState.registrationClosed,
    );
  });

  test('an invite-only event with no request yet shows requestToJoin', () {
    final event = _event(visibility: EventVisibility.inviteOnly);
    expect(
      resolveEventActionState(event: event, myId: 'me', isAttending: false),
      EventActionState.requestToJoin,
    );
  });

  test('a public event with room and no deadline shows join', () {
    expect(
      resolveEventActionState(event: _event(), myId: 'me', isAttending: false),
      EventActionState.join,
    );
  });

  test('join is actionable; every terminal/blocked state is not', () {
    expect(EventActionState.join.isActionable, isTrue);
    expect(EventActionState.requestToJoin.isActionable, isTrue);
    for (final state in [
      EventActionState.none,
      EventActionState.host,
      EventActionState.cancelled,
      EventActionState.ended,
      EventActionState.registered,
      EventActionState.pendingApproval,
      EventActionState.inProgress,
      EventActionState.full,
      EventActionState.registrationClosed,
    ]) {
      expect(state.isActionable, isFalse, reason: '$state should not be actionable');
    }
  });
}
