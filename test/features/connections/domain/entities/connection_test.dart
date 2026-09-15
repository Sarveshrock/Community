// Locks down Connection.fromJson's pet-name parsing and displayName() —
// the "Shivam (Shivu)" vs "Shivam" formatting is the whole point of
// Buddies, and it must never render the *other* party's private nickname
// for the viewer (connection_nicknames RLS restricts the embed to the
// caller's own row, but the Dart-side parsing must not assume more than one
// row could ever legitimately arrive).

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/connections/domain/entities/connection.dart';

Map<String, dynamic> _row({
  String requesterId = 'me',
  String receiverId = 'them',
  List<Map<String, dynamic>>? nicknames,
}) =>
    {
      'id': 'conn-1',
      'requester_id': requesterId,
      'receiver_id': receiverId,
      'status': 'accepted',
      'created_at': '2026-01-01T00:00:00Z',
      'receiver_profile': {
        'full_name': 'Shivam',
        'avatar_url': null,
        'current_role': 'Engineer'
      },
      if (nicknames != null) 'connection_nicknames': nicknames,
    };

void main() {
  test('displayName falls back to the main name when no pet name is set', () {
    final c = Connection.fromJson(_row(), viewerId: 'me');
    expect(c.petName, isNull);
    expect(c.displayName(), 'Shivam');
  });

  test('displayName appends the pet name in parentheses when set', () {
    final c = Connection.fromJson(
      _row(nicknames: [
        {'nickname': 'Shivu'}
      ]),
      viewerId: 'me',
    );
    expect(c.petName, 'Shivu');
    expect(c.displayName(), 'Shivam (Shivu)');
  });

  test(
      'an empty connection_nicknames embed (RLS hid the other party\'s row) parses as no pet name',
      () {
    final c = Connection.fromJson(_row(nicknames: const []), viewerId: 'me');
    expect(c.petName, isNull);
    expect(c.displayName(), 'Shivam');
  });

  test('otherProfileId resolves regardless of who initiated the connection',
      () {
    final asRequester = Connection.fromJson(
        _row(requesterId: 'me', receiverId: 'them'),
        viewerId: 'me');
    expect(asRequester.otherProfileId('me'), 'them');

    final asReceiver = Connection.fromJson(
        _row(requesterId: 'them', receiverId: 'me'),
        viewerId: 'me');
    expect(asReceiver.otherProfileId('me'), 'them');
  });

  test('parses location from city and country, joined with a comma', () {
    final row = _row()
      ..['receiver_profile'] = {
        'full_name': 'Shivam',
        'city': 'Bengaluru',
        'country': 'India',
      };
    final c = Connection.fromJson(row, viewerId: 'me');
    expect(c.otherProfileLocation, 'Bengaluru, India');
  });

  test('location falls back to whichever of city/country is set', () {
    final cityOnly = Connection.fromJson(
      _row()..['receiver_profile'] = {'full_name': 'Shivam', 'city': 'Pune'},
      viewerId: 'me',
    );
    expect(cityOnly.otherProfileLocation, 'Pune');

    final neither = Connection.fromJson(
      _row()..['receiver_profile'] = {'full_name': 'Shivam'},
      viewerId: 'me',
    );
    expect(neither.otherProfileLocation, isNull);
  });

  test('parses interest tags from the nested profile_interests embed', () {
    final row = _row()
      ..['receiver_profile'] = {
        'full_name': 'Shivam',
        'profile_interests': [
          {
            'interests': {'name': 'Study'}
          },
          {
            'interests': {'name': 'Communities'}
          },
        ],
      };
    final c = Connection.fromJson(row, viewerId: 'me');
    expect(c.otherProfileInterests, ['Study', 'Communities']);
  });

  test('interests default to empty (not null) when the embed is absent', () {
    final c = Connection.fromJson(_row(), viewerId: 'me');
    expect(c.otherProfileInterests, isEmpty);
  });

  test('parses bio and updated_at from the profile embed', () {
    final row = _row()
      ..['receiver_profile'] = {
        'full_name': 'Shivam',
        'bio': 'Building things for the web.',
        'updated_at': '2026-01-01T00:00:00Z',
      };
    final c = Connection.fromJson(row, viewerId: 'me');
    expect(c.otherProfileBio, 'Building things for the web.');
    expect(c.otherProfileUpdatedAt, DateTime.parse('2026-01-01T00:00:00Z'));
  });

  test('bio and updatedAt are null when absent from the embed', () {
    final c = Connection.fromJson(_row(), viewerId: 'me');
    expect(c.otherProfileBio, isNull);
    expect(c.otherProfileUpdatedAt, isNull);
  });

  group('BuddyPresence.fromUpdatedAt', () {
    test('within the last 15 minutes counts as Online', () {
      final presence = BuddyPresence.fromUpdatedAt(
          DateTime.now().subtract(const Duration(minutes: 5)));
      expect(presence.isOnline, isTrue);
      expect(presence.label, 'Online');
    });

    test('a few hours ago shows Offline with an hour count', () {
      final presence = BuddyPresence.fromUpdatedAt(
          DateTime.now().subtract(const Duration(hours: 4)));
      expect(presence.isOnline, isFalse);
      expect(presence.label, 'Offline · 4h');
    });

    test('a day or more ago shows Offline with a day count', () {
      final presence = BuddyPresence.fromUpdatedAt(
          DateTime.now().subtract(const Duration(days: 2)));
      expect(presence.isOnline, isFalse);
      expect(presence.label, 'Offline · 2d');
    });

    test('null (no profile activity data at all) shows plain Offline', () {
      final presence = BuddyPresence.fromUpdatedAt(null);
      expect(presence.isOnline, isFalse);
      expect(presence.label, 'Offline');
    });
  });
}
