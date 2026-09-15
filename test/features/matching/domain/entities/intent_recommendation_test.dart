// Locks down IntentRecommendation.fromJson's parsing of an
// intent_recommendations row (0052_recommendation_signals.sql) — every
// recommendation must carry explainable reasons, never just a bare score
// (same "always explainable" rule as MatchResult).

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/matching/domain/entities/intent_recommendation.dart';

void main() {
  test('IntentRecommendation.fromJson parses a full community recommendation row', () {
    final rec = IntentRecommendation.fromJson({
      'recommendation_type': 'community',
      'target_id': 'community-1',
      'title': 'AI Builders',
      'subtitle': 'Rahul is a member.',
      'image_url': 'https://x.test/c.png',
      'score': 78.5,
      'reasons': ['Rahul is a member.', '2 more of your connections are also a member.'],
      'ai_rationale': 'Rahul is a member of AI Builders, which matches the backend skills your Intent needs.',
      'signal_breakdown': {
        'compatibility': 0.92,
        'intentRelevance': 0.67,
        'socialProximity': 0.4,
        'recency': 1.0,
        'relationshipStrength': 0.5,
      },
    });

    expect(rec.recommendationType, RecommendationType.community);
    expect(rec.targetId, 'community-1');
    expect(rec.title, 'AI Builders');
    expect(rec.score, 78.5);
    expect(rec.reasons, hasLength(2));
    expect(rec.hasAiRationale, isTrue);
    expect(rec.signalBreakdown['compatibility'], 0.92);
  });

  test('IntentRecommendation.fromJson parses every recommendation type', () {
    for (final type in RecommendationType.values) {
      final rec = IntentRecommendation.fromJson({
        'recommendation_type': type.value,
        'target_id': 'x',
        'title': 'x',
        'score': 50,
      });
      expect(rec.recommendationType, type);
    }
  });

  test('an unrecognized recommendation_type falls back to community, never crashes', () {
    final rec = IntentRecommendation.fromJson({
      'recommendation_type': 'not-a-real-type',
      'target_id': 'x',
      'title': 'x',
      'score': 50,
    });
    expect(rec.recommendationType, RecommendationType.community);
  });

  test('defaults to empty reasons/breakdown and no rationale for a minimal row', () {
    final rec = IntentRecommendation.fromJson({
      'recommendation_type': 'event',
      'target_id': 'event-1',
      'title': 'AI Hackathon 2026',
      'score': 40,
    });

    expect(rec.reasons, isEmpty);
    expect(rec.signalBreakdown, isEmpty);
    expect(rec.aiRationale, isNull);
    expect(rec.hasAiRationale, isFalse);
    expect(rec.subtitle, isNull);
    expect(rec.imageUrl, isNull);
  });

  test('a null/blank ai_rationale is treated as no rationale', () {
    final nullRationale = IntentRecommendation.fromJson({
      'recommendation_type': 'post',
      'target_id': 'p1',
      'title': 't',
      'score': 10,
      'ai_rationale': null,
    });
    final blankRationale = IntentRecommendation.fromJson({
      'recommendation_type': 'post',
      'target_id': 'p2',
      'title': 't',
      'score': 10,
      'ai_rationale': '   ',
    });

    expect(nullRationale.hasAiRationale, isFalse);
    expect(blankRationale.hasAiRationale, isFalse);
  });

  test('RecommendationTypeX round-trips value <-> enum for every member', () {
    for (final type in RecommendationType.values) {
      expect(RecommendationTypeX.fromValue(type.value), type);
    }
  });
}
