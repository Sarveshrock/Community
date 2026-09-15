// Locks down the wire contract with the events table + its richer Phase 1
// columns (0042_events_rich_details.sql) and the nested host/event_tags
// embeds the repository's select produces.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/events/domain/entities/event.dart';

void main() {
  group('CommunityEvent.fromJson', () {
    test('maps a fully populated row, including nested host and tags', () {
      final event = CommunityEvent.fromJson({
        'id': 'event-1',
        'host_id': 'host-1',
        'host': {'full_name': 'Ada Lovelace', 'avatar_url': 'https://a.png'},
        'title': 'AI & Cloud Meetup',
        'short_description': 'A quick evening meetup',
        'description': 'Longer description here.',
        'event_type': 'meetup',
        'mode': 'hybrid',
        'starts_at': '2026-09-20T10:00:00Z',
        'ends_at': '2026-09-20T17:00:00Z',
        'is_all_day': false,
        'timezone': 'Asia/Kolkata',
        'cover_image_url': 'https://example.com/cover.jpg',
        'meeting_platform': 'Zoom',
        'venue_name': 'Community Hall',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'max_participants': 100,
        'registration_required': true,
        'visibility': 'invite_only',
        'audience': ['Developers', 'Students'],
        'is_free': false,
        'price': 499.0,
        'currency': 'INR',
        'what_to_bring': ['Laptop'],
        'prerequisites': 'Basic Python',
        'benefits': ['Certificate', 'Networking'],
        'status': 'published',
        'event_tags': [
          {
            'skills': {'name': 'AI'}
          },
          {
            'skills': {'name': 'Cloud'}
          },
        ],
        'event_attendees': [
          {'profile_id': 'u1'},
          {'profile_id': 'u2'},
        ],
      });

      expect(event.id, 'event-1');
      expect(event.hostName, 'Ada Lovelace');
      expect(event.hostAvatarUrl, 'https://a.png');
      expect(event.title, 'AI & Cloud Meetup');
      expect(event.shortDescription, 'A quick evening meetup');
      expect(event.eventType, 'meetup');
      expect(event.mode, 'hybrid');
      expect(event.isHybrid, isTrue);
      expect(event.timezone, 'Asia/Kolkata');
      expect(event.maxParticipants, 100);
      expect(event.visibility, EventVisibility.inviteOnly);
      expect(event.audience, ['Developers', 'Students']);
      expect(event.isFree, isFalse);
      expect(event.price, 499.0);
      expect(event.whatToBring, ['Laptop']);
      expect(event.benefits, ['Certificate', 'Networking']);
      expect(event.tags, ['AI', 'Cloud']);
      expect(event.attendeeCount, 2);
      expect(event.status, EventStatus.published);
      expect(event.isCancelled, isFalse);
    });

    test('falls back to sensible defaults for a minimal row', () {
      final event = CommunityEvent.fromJson({
        'id': 'event-2',
        'host_id': 'host-2',
        'title': 'Minimal event',
        'starts_at': '2026-09-20T10:00:00Z',
      });

      expect(event.eventType, 'community_event');
      expect(event.mode, 'online');
      expect(event.isOnline, isTrue);
      expect(event.visibility, EventVisibility.public);
      expect(event.isFree, isTrue);
      expect(event.audience, isEmpty);
      expect(event.tags, isEmpty);
      expect(event.attendeeCount, 0);
      expect(event.status, EventStatus.published);
    });

    test('sensitive fields (meeting_url, address) come back null when the '
        'repository omits the private-details embed for an unauthorized viewer', () {
      final event = CommunityEvent.fromJson({
        'id': 'event-3',
        'host_id': 'host-1',
        'title': 'Private-ish event',
        'starts_at': '2026-09-20T10:00:00Z',
        // No event_private_details key at all — RLS hid the row.
      });

      expect(event.meetingUrl, isNull);
      expect(event.address, isNull);
    });
  });

  group('CommunityEvent computed state', () {
    test('isFull is true once attendeeCount reaches maxParticipants', () {
      final event = CommunityEvent(
        id: '1',
        hostId: 'h',
        title: 't',
        startsAt: DateTime.now(),
        maxParticipants: 2,
        attendeeCount: 2,
      );
      expect(event.isFull, isTrue);
    });

    test('isFull is false with no maxParticipants set (unlimited)', () {
      final event = CommunityEvent(id: '1', hostId: 'h', title: 't', startsAt: DateTime.now(), attendeeCount: 500);
      expect(event.isFull, isFalse);
    });

    test('registrationClosed reflects the deadline, not the event start time', () {
      final closed = CommunityEvent(
        id: '1',
        hostId: 'h',
        title: 't',
        startsAt: DateTime.now().add(const Duration(days: 5)),
        registrationDeadline: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final open = CommunityEvent(
        id: '2',
        hostId: 'h',
        title: 't',
        startsAt: DateTime.now().add(const Duration(days: 5)),
        registrationDeadline: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(closed.registrationClosed, isTrue);
      expect(open.registrationClosed, isFalse);
    });
  });

  test('eventTypeLabel title-cases unknown/simple values and special-cases known ones', () {
    expect(eventTypeLabel('tech_talk'), 'Tech Talk');
    expect(eventTypeLabel('study_session'), 'Study Session');
    expect(eventTypeLabel('community_event'), 'Community Event');
    expect(eventTypeLabel('webinar'), 'Webinar');
  });
}
