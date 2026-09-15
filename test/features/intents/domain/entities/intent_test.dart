// Locks down UserIntent.fromJson's intent_skills parsing (needed vs offered
// direction) and the derive-don't-store expiry logic that 0036_intents.sql's
// RLS policy mirrors server-side — a mismatch here means an expired intent
// either lingers in "Active" or a live one wrongly disappears.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/intents/domain/entities/intent.dart';

Map<String, dynamic> _baseJson({
  String status = 'active',
  required DateTime expiresAt,
  List<Map<String, dynamic>> skillRows = const [],
}) {
  return {
    'id': 'intent-1',
    'profile_id': 'user-1',
    'intent_type': 'find_hackathon_teammates',
    'title': 'Need an ML engineer for a hackathon',
    'status': status,
    'expires_at': expiresAt.toIso8601String(),
    'created_at': '2026-01-01T00:00:00Z',
    'intent_skills': skillRows,
  };
}

void main() {
  test('UserIntent.fromJson splits intent_skills into needed vs offered', () {
    final intent = UserIntent.fromJson(_baseJson(
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      skillRows: [
        {
          'direction': 'needed',
          'skills': {'name': 'Machine Learning'},
        },
        {
          'direction': 'needed',
          'skills': {'name': 'PyTorch'},
        },
        {
          'direction': 'offered',
          'skills': {'name': 'Flutter'},
        },
      ],
    ));

    expect(intent.skillsNeeded, ['Machine Learning', 'PyTorch']);
    expect(intent.skillsOffered, ['Flutter']);
    expect(intent.intentType, IntentType.findHackathonTeammates);
  });

  test('UserIntent.fromJson tolerates a missing intent_skills relation', () {
    final json = _baseJson(expiresAt: DateTime.now().add(const Duration(days: 7)))
      ..remove('intent_skills');
    final intent = UserIntent.fromJson(json);

    expect(intent.skillsNeeded, isEmpty);
    expect(intent.skillsOffered, isEmpty);
  });

  test('isExpired/isEffectivelyActive: active + future expiry is effectively active', () {
    final intent = UserIntent.fromJson(
        _baseJson(status: 'active', expiresAt: DateTime.now().add(const Duration(days: 1))));
    expect(intent.isExpired, isFalse);
    expect(intent.isEffectivelyActive, isTrue);
  });

  test('isExpired/isEffectivelyActive: active + past expiry is expired, not active', () {
    final intent = UserIntent.fromJson(
        _baseJson(status: 'active', expiresAt: DateTime.now().subtract(const Duration(days: 1))));
    expect(intent.isExpired, isTrue);
    expect(intent.isEffectivelyActive, isFalse);
  });

  test('isExpired/isEffectivelyActive: paused + future expiry is not effectively active', () {
    final intent = UserIntent.fromJson(
        _baseJson(status: 'paused', expiresAt: DateTime.now().add(const Duration(days: 1))));
    expect(intent.isExpired, isFalse);
    expect(intent.isEffectivelyActive, isFalse);
  });

  test('isExpired/isEffectivelyActive: cancelled is never effectively active', () {
    final intent = UserIntent.fromJson(
        _baseJson(status: 'cancelled', expiresAt: DateTime.now().add(const Duration(days: 30))));
    expect(intent.isEffectivelyActive, isFalse);
  });

  test('fromJson tolerates a pre-0048 row with no metadata column at all', () {
    final json = _baseJson(expiresAt: DateTime.now().add(const Duration(days: 7)));
    final intent = UserIntent.fromJson(json);
    expect(intent.metadata, isEmpty);
    expect(intent.isFulfilled, isFalse);
  });

  test('fromJson round-trips metadata (0048_intent_structured_details.sql)', () {
    final json = _baseJson(expiresAt: DateTime.now().add(const Duration(days: 7)));
    json['metadata'] = {'role_needed': 'Backend', 'skills': ['Go', 'Postgres']};
    final intent = UserIntent.fromJson(json);
    expect(intent.metadata['role_needed'], 'Backend');
    expect(intent.metadata['skills'], ['Go', 'Postgres']);
  });

  test('networking is a valid, round-trippable IntentType', () {
    final json = _baseJson(expiresAt: DateTime.now().add(const Duration(days: 7)));
    json['intent_type'] = 'networking';
    final intent = UserIntent.fromJson(json);
    expect(intent.intentType, IntentType.networking);
    expect(intent.intentType.label, 'Networking');
  });

  test('statusLabel: fulfilled beats every other derived state', () {
    final intent = UserIntent.fromJson(
        _baseJson(status: 'fulfilled', expiresAt: DateTime.now().subtract(const Duration(days: 1))));
    expect(intent.isFulfilled, isTrue);
    expect(intent.statusLabel, 'Fulfilled');
  });

  test('statusLabel: active with expiry within 3 days reads as Expiring Soon', () {
    final intent = UserIntent.fromJson(
        _baseJson(status: 'active', expiresAt: DateTime.now().add(const Duration(days: 2))));
    expect(intent.statusLabel, 'Expiring Soon');
  });

  test('statusLabel: active with plenty of runway reads as Active', () {
    final intent = UserIntent.fromJson(
        _baseJson(status: 'active', expiresAt: DateTime.now().add(const Duration(days: 20))));
    expect(intent.statusLabel, 'Active');
  });

  test('statusLabel: past expiry reads as Expired even if status is still active', () {
    final intent = UserIntent.fromJson(
        _baseJson(status: 'active', expiresAt: DateTime.now().subtract(const Duration(hours: 1))));
    expect(intent.statusLabel, 'Expired');
  });

  test('daysUntilExpiry never goes negative once past expiry', () {
    final intent = UserIntent.fromJson(
        _baseJson(status: 'active', expiresAt: DateTime.now().subtract(const Duration(days: 10))));
    expect(intent.daysUntilExpiry, 0);
  });
}
