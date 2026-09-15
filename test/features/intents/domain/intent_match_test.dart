// Locks down the deterministic, non-AI reciprocal match score — spec's own
// example: "User A needs Python+AI/ML, offers React+UI/UX" reciprocally
// matching "User B needs React+UI/UX, offers Python+AI/ML".

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/intents/domain/entities/intent.dart';
import 'package:community_app/features/intents/domain/intent_match.dart';

UserIntent _intent({
  required List<String> needed,
  required List<String> offered,
}) {
  return UserIntent(
    id: 'i',
    profileId: 'p',
    intentType: IntentType.findCollaborator,
    title: 't',
    expiresAt: DateTime.now().add(const Duration(days: 7)),
    createdAt: DateTime.now(),
    skillsNeeded: needed,
    skillsOffered: offered,
  );
}

void main() {
  test('full reciprocal match: each side offers exactly what the other needs', () {
    final mine = _intent(needed: ['Python', 'AI/ML'], offered: ['React', 'UI/UX']);
    final other = _intent(needed: ['React', 'UI/UX'], offered: ['Python', 'AI/ML']);

    final result = computeReciprocalIntentMatch(mine: mine, other: other);

    expect(result, isNotNull);
    expect(result!.percent, 100);
    expect(result.theyOfferYouNeed, containsAll(['Python', 'AI/ML']));
    expect(result.youOfferTheyNeed, containsAll(['React', 'UI/UX']));
    expect(result.hasAnyMatch, isTrue);
  });

  test('partial match scores below 100 and still reports what did overlap', () {
    final mine = _intent(needed: ['Python', 'AI/ML'], offered: ['React']);
    final other = _intent(needed: ['React'], offered: ['Python']);

    final result = computeReciprocalIntentMatch(mine: mine, other: other);

    expect(result, isNotNull);
    expect(result!.percent, lessThan(100));
    expect(result.percent, greaterThan(0));
  });

  test('no overlap at all returns a zero-percent, no-match result', () {
    final mine = _intent(needed: ['Rust'], offered: ['Go']);
    final other = _intent(needed: ['Java'], offered: ['C++']);

    final result = computeReciprocalIntentMatch(mine: mine, other: other);

    expect(result, isNotNull);
    expect(result!.percent, 0);
    expect(result.hasAnyMatch, isFalse);
  });

  test('both intents having nothing needed/offered returns null (nothing to compare)', () {
    final mine = _intent(needed: [], offered: []);
    final other = _intent(needed: [], offered: []);

    expect(computeReciprocalIntentMatch(mine: mine, other: other), isNull);
  });

  test('matching is case-insensitive', () {
    final mine = _intent(needed: ['python'], offered: []);
    final other = _intent(needed: [], offered: ['PYTHON']);

    final result = computeReciprocalIntentMatch(mine: mine, other: other);
    expect(result, isNotNull);
    // Overlap preserves the casing of what I need, not what they offer.
    expect(result!.theyOfferYouNeed, ['python']);
  });
}
