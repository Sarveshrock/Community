// Flexible scoring for cross-entity recommendations (community/event/
// project/post) surfaced through a person the caller already has a
// compatibility score with (an Intent match) — never a bare "score >= 70"
// gate. A 65%-compatible source person with strong social proximity and
// exact Intent-skill relevance can outscore an 85%-compatible person with
// no other signal, by design (spec-extension: Personalized Opportunity &
// Network Intelligence). Mirrors _shared/scoring.ts's shape (components +
// weights -> a single 0-100 score) but is a distinct abstraction since it
// scores different entity types, not people.

export interface RecommendationSignals {
  /// The source person's own Intent-match compatibility, 0-1 (their
  /// `intent_matches.score / 100`).
  compatibility: number;
  /// Overlap between the Intent's needed skills and this entity's tagged
  /// skills (community_topics/event_tags/project_required_skills), 0-1.
  intentRelevance: number;
  /// Fraction of the caller's own accepted connections who are also
  /// involved with this entity (member/attendee/interested/liked), 0-1.
  socialProximity: number;
  /// Freshness signal, 0-1 — recent posts score higher, past/far-future
  /// events are excluded upstream rather than scored down here.
  recency: number;
  /// 1.0 if the source person is a direct (accepted) connection of the
  /// caller, 0.5 if they're only an Intent-match with no existing
  /// connection — reflects the spec's "relationship strength" component.
  relationshipStrength: number;
}

export interface RecommendationWeights {
  compatibility: number;
  intentRelevance: number;
  socialProximity: number;
  recency: number;
  relationshipStrength: number;
}

// Sums to 1.0. Kept as a plain exported constant (not read from a DB table
// like ai_scoring_weights) for the same reason ai-match-intent hardcodes its
// own weights: these recommendation types aren't a `recommendation_type`
// value yet — a clean, obvious follow-up, not a blocker for this pass.
export const DEFAULT_RECOMMENDATION_WEIGHTS: RecommendationWeights = {
  compatibility: 0.30,
  intentRelevance: 0.25,
  socialProximity: 0.20,
  recency: 0.10,
  relationshipStrength: 0.15,
};

export function clamp01(value: number): number {
  if (Number.isNaN(value)) return 0;
  return Math.max(0, Math.min(1, value));
}

/// Same shape/semantics as _shared/scoring.ts's jaccard — kept local rather
/// than imported so this file has no dependency on the people-matching
/// module it's conceptually separate from.
export function overlapRatio(a: string[], b: string[]): number {
  if (a.length === 0 || b.length === 0) return 0;
  const setB = new Set(b.map((x) => x.toLowerCase()));
  const matched = a.filter((x) => setB.has(x.toLowerCase())).length;
  return matched / a.length;
}

export function recommendationScore(
  signals: RecommendationSignals,
  weights: RecommendationWeights = DEFAULT_RECOMMENDATION_WEIGHTS,
): number {
  const raw =
    clamp01(signals.compatibility) * weights.compatibility +
    clamp01(signals.intentRelevance) * weights.intentRelevance +
    clamp01(signals.socialProximity) * weights.socialProximity +
    clamp01(signals.recency) * weights.recency +
    clamp01(signals.relationshipStrength) * weights.relationshipStrength;
  return Math.round(clamp01(raw) * 100 * 100) / 100; // 0-100, 2dp
}

/// Normalizes "N of the caller's connections are also involved" into 0-1 —
/// diminishing returns past a handful, so one hyper-connected community
/// doesn't structurally dominate every recommendation.
export function socialProximityFromCount(count: number, cap = 5): number {
  if (count <= 0) return 0;
  return clamp01(count / cap);
}

/// Linear recency decay over `halfLifeDays` — a post from today scores 1.0,
/// one from `halfLifeDays` ago scores 0.5, older keeps decaying toward 0
/// rather than being hard-cut, so a genuinely great older post can still
/// surface on strong compatibility/relevance alone.
export function recencyScore(createdAt: string | Date, halfLifeDays = 7): number {
  const ageMs = Date.now() - new Date(createdAt).getTime();
  const ageDays = ageMs / (1000 * 60 * 60 * 24);
  if (ageDays <= 0) return 1;
  return clamp01(1 - ageDays / (halfLifeDays * 2));
}
