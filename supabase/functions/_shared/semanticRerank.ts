// Optional semantic re-ranking pass (spec section 43's pipeline: Deterministic
// Scoring -> Optional Semantic Ranking -> Privacy Filtering -> Final
// Recommendations). No-op unless an AI provider is configured; any provider
// failure falls back silently to the deterministic order so a flaky/slow AI
// call never breaks recommendations.

import { AiProvider, isAiConfigured } from "./aiProvider.ts";

export interface Scored<T> {
  item: T;
  id: string;
  score: number;
  reason: string;
}

/// Blends each candidate's deterministic `score` (0-1) with the AI's
/// relevance score (0-100, normalized to 0-1) and re-sorts. Weighted 70/30
/// toward the deterministic score so semantic ranking nudges order rather
/// than overriding the transparent, explainable weights from section 43.
export async function applySemanticReranking<T>(
  ai: AiProvider,
  queryText: string,
  scored: Scored<T>[],
  textOf: (item: T) => string,
): Promise<Scored<T>[]> {
  if (!isAiConfigured() || scored.length === 0) return scored;

  try {
    const ranked = await ai.rankCandidates(
      queryText,
      scored.map((s) => ({ id: s.id, text: textOf(s.item) })),
    );
    const aiScoreById = new Map(ranked.map((r) => [r.id, r.score]));

    const blended = scored.map((s) => {
      const aiScore = aiScoreById.get(s.id);
      if (aiScore === undefined) return s;
      const normalizedAi = Math.max(0, Math.min(100, aiScore)) / 100;
      return { ...s, score: s.score * 0.7 + normalizedAi * 0.3 };
    });
    blended.sort((a, b) => b.score - a.score);
    return blended;
  } catch {
    // AI provider errored — keep the deterministic ranking.
    return scored;
  }
}
