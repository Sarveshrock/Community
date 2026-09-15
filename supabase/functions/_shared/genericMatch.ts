// Shared skill/interest-based matching used by the ai-match-* functions that
// rank content (jobs, projects, team requirements, startup opportunities,
// mentors) against a caller's profile. Keeps each function file thin.

import { serviceClient } from "./supabaseClient.ts";
import { jaccard, reasonFromComponents, weightedScore, ScoringWeights } from "./scoring.ts";
import { getAiProvider, matchModelVersion } from "./aiProvider.ts";
import { applySemanticReranking, Scored } from "./semanticRerank.ts";

export interface MatchTarget {
  id: string;
  requiredSkillNames: string[];
  text: string;
}

export async function getCallerSkillsAndInterests(callerId: string) {
  const db = serviceClient();
  const [{ data: skills }, { data: interests }] = await Promise.all([
    db.from("profile_skills").select("skills(normalized_name)").eq("profile_id", callerId),
    db.from("profile_interests").select("interests(normalized_name)").eq("profile_id", callerId),
  ]);
  return {
    skillNames: (skills ?? []).map((s: any) => s.skills?.normalized_name).filter(Boolean) as string[],
    interestNames: (interests ?? []).map((s: any) => s.interests?.normalized_name).filter(Boolean) as string[],
  };
}

export async function getWeights(type: string): Promise<ScoringWeights> {
  const db = serviceClient();
  const { data } = await db.from("ai_scoring_weights").select("*").eq("recommendation_type", type).single();
  return (
    data ?? {
      skills_weight: 0.4,
      interests_weight: 0.2,
      goals_weight: 0.1,
      experience_weight: 0.1,
      availability_weight: 0.1,
      location_weight: 0.05,
      activity_weight: 0.05,
    }
  );
}

export function rankTargets(
  targets: MatchTarget[],
  callerSkills: string[],
  callerInterests: string[],
  weights: ScoringWeights,
) {
  const scored = targets.map((t) => {
    const skillsScore = jaccard(callerSkills, t.requiredSkillNames);
    const textTokens = t.text.toLowerCase().split(/\W+/);
    const interestsScore = jaccard(callerInterests, textTokens);
    const components = {
      skills: skillsScore,
      interests: interestsScore,
      goals: 0,
      experience: 0,
      availability: 0.5,
      location: 0,
      activity: 0.5,
    };
    return {
      id: t.id,
      score: weightedScore(components, weights),
      reason: reasonFromComponents(components),
    };
  });
  scored.sort((a, b) => b.score - a.score);
  return scored;
}

/// Deterministic ranking followed by an optional semantic re-ranking pass
/// (spec section 43) — a no-op unless AI_PROVIDER is configured, and any AI
/// failure falls back to the deterministic order.
export async function rankTargetsWithAi(
  targets: MatchTarget[],
  callerSkills: string[],
  callerInterests: string[],
  weights: ScoringWeights,
  limit: number,
): Promise<{ id: string; score: number; reason: string }[]> {
  const deterministic = rankTargets(targets, callerSkills, callerInterests, weights);
  const targetById = new Map(targets.map((t) => [t.id, t]));

  const pool: Scored<MatchTarget>[] = deterministic
    .slice(0, Math.max(limit * 2, 20))
    .map((d) => ({ item: targetById.get(d.id)!, id: d.id, score: d.score, reason: d.reason }));

  const ai = getAiProvider();
  const reranked = await applySemanticReranking(
    ai,
    `Someone with skills: ${callerSkills.join(", ") || "none listed"} and interests: ${
      callerInterests.join(", ") || "none listed"
    }.`,
    pool,
    (t) => t.text,
  );

  return reranked.slice(0, limit).map((r) => ({ id: r.id, score: r.score, reason: r.reason }));
}

export async function storeRecommendations(
  profileId: string,
  type: string,
  ranked: { id: string; score: number; reason: string }[],
) {
  const db = serviceClient();
  const rows = ranked.map((r) => ({
    profile_id: profileId,
    candidate_id: r.id,
    recommendation_type: type,
    score: r.score,
    reason: r.reason,
    model_version: matchModelVersion(),
  }));
  if (rows.length > 0) await db.from("ai_recommendations").insert(rows);
}
