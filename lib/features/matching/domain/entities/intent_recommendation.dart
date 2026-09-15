/// A cross-entity recommendation (community/event/project/post) surfaced
/// because a person compatible with the caller's Intent (see [MatchResult])
/// is visibly, publicly involved with it — the "Communeo Intelligence"
/// layer's counterpart to a person match. Mirrors `intent_matches`'/
/// [MatchResult]'s own "always explainable" rule: [reasons] is never empty,
/// and [aiRationale] (when present) is a richer restatement of the same
/// grounded facts, never information the deterministic signals didn't
/// already establish.
enum RecommendationType { community, event, project, post }

extension RecommendationTypeX on RecommendationType {
  String get value => switch (this) {
        RecommendationType.community => 'community',
        RecommendationType.event => 'event',
        RecommendationType.project => 'project',
        RecommendationType.post => 'post',
      };

  String get label => switch (this) {
        RecommendationType.community => 'Community',
        RecommendationType.event => 'Event',
        RecommendationType.project => 'Project',
        RecommendationType.post => 'Post',
      };

  static RecommendationType fromValue(String? value) => switch (value) {
        'event' => RecommendationType.event,
        'project' => RecommendationType.project,
        'post' => RecommendationType.post,
        _ => RecommendationType.community,
      };
}

class IntentRecommendation {
  const IntentRecommendation({
    required this.recommendationType,
    required this.targetId,
    required this.title,
    required this.score,
    this.subtitle,
    this.imageUrl,
    this.reasons = const [],
    this.aiRationale,
    this.signalBreakdown = const {},
  });

  final RecommendationType recommendationType;
  final String targetId;
  final String title;
  final String? subtitle;
  final String? imageUrl;

  /// 0-100 — from the flexible multi-signal formula in
  /// `_shared/recommendationScoring.ts` (compatibility + Intent relevance +
  /// social proximity + recency + relationship strength). Never a bare
  /// compatibility percentage, and never gated behind a hardcoded threshold.
  final num score;
  final List<String> reasons;

  /// A real, LLM-generated "why am I seeing this" sentence — null when no AI
  /// provider is configured or this recommendation fell outside the top few
  /// sent for rationale generation. [reasons] is always present regardless.
  final String? aiRationale;

  /// Individual signal components behind [score] (compatibility/
  /// intentRelevance/socialProximity/recency/relationshipStrength, each
  /// 0-1) — keys match `signal_breakdown` from get-network-recommendations.
  final Map<String, num> signalBreakdown;

  bool get hasAiRationale => aiRationale != null && aiRationale!.trim().isNotEmpty;

  factory IntentRecommendation.fromJson(Map<String, dynamic> json) {
    return IntentRecommendation(
      recommendationType: RecommendationTypeX.fromValue(json['recommendation_type'] as String?),
      targetId: json['target_id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      imageUrl: json['image_url'] as String?,
      score: json['score'] as num,
      reasons: (json['reasons'] as List<dynamic>?)?.cast<String>() ?? const [],
      aiRationale: json['ai_rationale'] as String?,
      signalBreakdown: (json['signal_breakdown'] as Map<String, dynamic>?)?.cast<String, num>() ?? const {},
    );
  }
}
