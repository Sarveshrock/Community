// Locks down MatchResult.fromJson's parsing of an intent_matches row joined
// to profiles — every match must carry explainable reasons, never just a
// bare score (spec-extension: Matching Engine).

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/matching/domain/entities/match_result.dart';

void main() {
  test('MatchResult.fromJson parses reasons and skill breakdowns from a joined row', () {
    final match = MatchResult.fromJson({
      'candidate_id': 'user-2',
      'score': 92,
      'reasons': [
        'They have the skills you need: Machine Learning',
        'Available at compatible times',
      ],
      'matched_skills': ['Machine Learning'],
      'missing_skills': ['MLOps'],
      'complementary_skills': ['PyTorch'],
      'shared_interests': ['AI'],
      'availability_compatible': true,
      'profiles': {
        'full_name': 'Rahul',
        'avatar_url': 'https://x.test/r.png',
        'current_role': 'ML Engineer',
        'current_company': 'Acme',
      },
    });

    expect(match.candidateId, 'user-2');
    expect(match.score, 92);
    expect(match.reasons, hasLength(2));
    expect(match.matchedSkills, ['Machine Learning']);
    expect(match.missingSkills, ['MLOps']);
    expect(match.complementarySkills, ['PyTorch']);
    expect(match.sharedInterests, ['AI']);
    expect(match.availabilityCompatible, isTrue);
    expect(match.displayName, 'Rahul');
    expect(match.currentRole, 'ML Engineer');
  });

  test('MatchResult.fromJson defaults to empty breakdowns and falls back to "Community member"', () {
    final match = MatchResult.fromJson({
      'candidate_id': 'user-3',
      'score': 40,
    });

    expect(match.reasons, isEmpty);
    expect(match.matchedSkills, isEmpty);
    expect(match.availabilityCompatible, isNull);
    expect(match.displayName, 'Community member');
    expect(match.aiRationale, isNull);
    expect(match.hasAiRationale, isFalse);
    expect(match.scoreBreakdown, isEmpty);
  });

  test('MatchResult.fromJson parses a real LLM-generated rationale and score breakdown', () {
    final match = MatchResult.fromJson({
      'candidate_id': 'user-4',
      'score': 88,
      'ai_rationale': 'Rahul has exactly the backend skills you need for your fintech co-founder search.',
      'score_breakdown': {'skills': 1.0, 'interests': 0.67, 'experience': 1.0, 'availability': 1.0},
    });

    expect(match.hasAiRationale, isTrue);
    expect(match.aiRationale, contains('fintech co-founder'));
    expect(match.scoreBreakdown['skills'], 1.0);
    expect(match.scoreBreakdown['availability'], 1.0);
  });

  test('MatchResult.fromJson treats a null/blank ai_rationale as no rationale, never a crash', () {
    final nullRationale = MatchResult.fromJson({'candidate_id': 'user-5', 'score': 50, 'ai_rationale': null});
    final blankRationale = MatchResult.fromJson({'candidate_id': 'user-6', 'score': 50, 'ai_rationale': '   '});

    expect(nullRationale.hasAiRationale, isFalse);
    expect(blankRationale.hasAiRationale, isFalse);
  });
}
