// Overall ranking (spec section 8): freshness + tech relevance + importance
// + trending + source quality, combined via configurable weights (read
// from news_ranking_config, never hardcoded — see the migration).

import { RawNewsItem } from "../utils/types.ts";
import { clampScore } from "../utils/normalization.ts";
import { sourceQuality } from "./deduplication.ts";

export interface RankingWeights {
  weight_freshness: number;
  weight_tech_relevance: number;
  weight_importance: number;
  weight_trending: number;
  weight_source_quality: number;
}

/// Full score at <2h old, decaying to 0 by 7 days — matches how fast a tech
/// news cycle actually moves (unlike research, which ages more slowly, but
/// a single freshness curve keeps this simple and is corrected for by
/// research's high source-quality/importance weighting instead).
export function freshnessScore(publishedAt?: string): number {
  if (!publishedAt) return 40;
  const ageHours = (Date.now() - new Date(publishedAt).getTime()) / 3_600_000;
  if (ageHours < 0) return 100;
  return clampScore(100 - (ageHours / 168) * 100);
}

/// "Is this a big deal" — derived from whatever community/engagement
/// signal each source actually provides, never invented (spec section 10:
/// "Do not claim a paper is important solely because it is new").
export function importanceScore(item: RawNewsItem): number {
  const m = item.metadata ?? {};
  let score = 30;

  const points = Number(m.points ?? 0);
  if (points) score += Math.min(points / 5, 30);
  const comments = Number(m.num_comments ?? 0);
  if (comments) score += Math.min(comments / 3, 15);

  const stars = Number(m.stars ?? 0);
  if (stars) score += Math.min(Math.log10(stars + 1) * 8, 30);

  const citations = Number(m.citation_count ?? 0);
  if (citations) score += Math.min(Math.log10(citations + 1) * 10, 25);

  const metrics = m.public_metrics as Record<string, number> | undefined;
  if (metrics) {
    const engagement = (metrics.like_count ?? 0) + (metrics.retweet_count ?? 0) * 2 + (metrics.reply_count ?? 0);
    score += Math.min(engagement / 20, 25);
  }

  return clampScore(score);
}

/// Our own trending signal per source (spec section 9's github_trending_score
/// for GitHub items; community velocity proxy for HN/Show HN; a modest
/// default elsewhere — never a fabricated "trending" claim).
export function trendingScoreFor(item: RawNewsItem): number {
  const m = item.metadata ?? {};
  if (typeof m.github_trending_score === "number") return clampScore(m.github_trending_score as number);

  const points = Number(m.points ?? 0);
  const comments = Number(m.num_comments ?? 0);
  if (points || comments) return clampScore(points / 3 + comments / 2);

  return 20;
}

export interface ScoredItem extends RawNewsItem {
  content_hash: string;
  tech_relevance_score: number;
  importance_score: number;
  trending_score: number;
  final_score: number;
  category: string;
  tags: string[];
}

export function computeFinalScore(
  freshness: number,
  techRelevance: number,
  importance: number,
  trending: number,
  sourceQualityScore: number,
  weights: RankingWeights,
): number {
  return clampScore(
    freshness * weights.weight_freshness +
      techRelevance * weights.weight_tech_relevance +
      importance * weights.weight_importance +
      trending * weights.weight_trending +
      sourceQualityScore * weights.weight_source_quality,
  );
}

export function rankItem(
  item: RawNewsItem & { content_hash: string },
  relevance: { score: number; category: string; tags: string[] },
  weights: RankingWeights,
): ScoredItem {
  const freshness = freshnessScore(item.published_at);
  const importance = importanceScore(item);
  const trending = trendingScoreFor(item);
  const srcQuality = sourceQuality(item.source);
  const final = computeFinalScore(freshness, relevance.score, importance, trending, srcQuality, weights);

  return {
    ...item,
    tech_relevance_score: relevance.score,
    importance_score: importance,
    trending_score: trending,
    final_score: final,
    category: relevance.category,
    tags: relevance.tags,
  };
}
