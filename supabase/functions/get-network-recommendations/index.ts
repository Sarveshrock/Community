// get-network-recommendations
//
// "Communeo Intelligence" — the cross-entity counterpart to ai-match-intent.
// Deliberately does NOT recompute people-matching: it reads the top rows
// ai-match-intent already scored and stored in `intent_matches`, then
// surfaces what those (already-compatible) people are visibly, publicly
// doing — communities, upcoming events, open projects, recent posts — so a
// user's current Intent connects to the *ecosystem* around their goal, not
// just a list of people.
//
// Deterministic scoring decides what's relevant (recommendationScore.ts);
// AI only ever explains an already-decided recommendation in plain language
// (matchRationale.ts's generateRecommendationRationales) — it never picks
// candidates itself, and it is only ever given the structured facts this
// function already computed, so it cannot invent a connection, a skill, or
// an event attendance that isn't real.
//
// Every underlying query reads exactly what RLS already treats as public
// (private communities are explicitly excluded; events/projects/posts have
// no private-row concept in this schema) — nothing here uses service-role
// access to see past what the caller could already see themselves.

import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { requireUserId, serviceClient, userClient } from "../_shared/supabaseClient.ts";
import {
  findCommunityRecommendations,
  findEventRecommendations,
  findPostRecommendations,
  findProjectRecommendations,
  type RawRecommendation,
  type SourcePerson,
} from "../_shared/networkSignals.ts";
import { getAiProvider } from "../_shared/aiProvider.ts";
import { generateRecommendationRationales } from "../_shared/matchRationale.ts";
import { withTimeout } from "../_shared/timeout.ts";

// How many of the top people-matches become "source people" whose public
// activity gets scanned — bounded so this stays a handful of batched
// queries, never proportional to the whole candidate pool ai-match-intent
// considered.
const SOURCE_PERSON_COUNT = 5;

// At most this many recommendations per category, and this many overall —
// a "For You" section, not a second feed.
const MAX_PER_CATEGORY = 2;
const MAX_TOTAL = 6;

const AI_RATIONALE_COUNT = 6; // covers every recommendation we might keep
const AI_RATIONALE_TIMEOUT_MS = 8000;

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  try {
    const callerId = await requireUserId(req);
    const { intent_id } = await req.json();
    if (!intent_id) throw new Error("intent_id is required");

    const asUser = userClient(req);
    const { data: intent, error: intentError } = await asUser
      .from("intents")
      .select("id, profile_id")
      .eq("id", intent_id)
      .single();
    if (intentError || !intent) throw new Error("intent not found");
    if (intent.profile_id !== callerId) throw new Error("not your intent");

    const db = serviceClient();

    const { data: neededRows } = await db
      .from("intent_skills")
      .select("skills(name)")
      .eq("intent_id", intent_id)
      .eq("direction", "needed");
    const neededSkillNames: string[] = (neededRows ?? [])
      .map((r: any) => r.skills?.name as string | undefined)
      .filter((x: string | undefined): x is string => !!x);

    // Reuse ai-match-intent's already-computed, already-ranked top matches —
    // this function never re-scores people, only builds on the result.
    const { data: topMatchRows } = await db
      .from("intent_matches")
      .select("candidate_id, score, profiles(full_name)")
      .eq("intent_id", intent_id)
      .order("score", { ascending: false })
      .limit(SOURCE_PERSON_COUNT);

    if (!topMatchRows || topMatchRows.length === 0) {
      return jsonResponse({ recommendations: [] });
    }

    const { data: connectionRows } = await db.rpc("accepted_connection_ids", { p: callerId });
    const callerConnectionIds: string[] = (connectionRows ?? []).map((r: any) => (typeof r === "string" ? r : r.accepted_connection_ids));
    const connectionIdSet = new Set(callerConnectionIds);

    const sources: SourcePerson[] = topMatchRows.map((r: any) => ({
      id: r.candidate_id as string,
      fullName: (r.profiles?.full_name as string | undefined) ?? "Someone in your matches",
      compatibility: (r.score as number) / 100,
      isDirectConnection: connectionIdSet.has(r.candidate_id as string),
    }));

    const [communities, events, projects, posts] = await Promise.all([
      findCommunityRecommendations(db, sources, neededSkillNames, callerConnectionIds),
      findEventRecommendations(db, sources, neededSkillNames, callerConnectionIds),
      findProjectRecommendations(db, sources, neededSkillNames, callerConnectionIds),
      findPostRecommendations(db, sources, neededSkillNames, callerConnectionIds),
    ]);

    const byCategory: RawRecommendation[][] = [communities, events, projects, posts];
    const capped: RawRecommendation[] = [];
    for (const category of byCategory) {
      category.sort((a, b) => b.score - a.score);
      capped.push(...category.slice(0, MAX_PER_CATEGORY));
    }
    capped.sort((a, b) => b.score - a.score);
    const top = capped.slice(0, MAX_TOTAL);

    const rationaleTargets = top.slice(0, AI_RATIONALE_COUNT);
    const rationaleById = await withTimeout(
      generateRecommendationRationales(
        getAiProvider(),
        neededSkillNames.length > 0 ? `someone with skills: ${neededSkillNames.join(", ")}` : "their current Intent",
        rationaleTargets.map((r) => ({ id: `${r.recommendationType}:${r.targetId}`, summary: r.factSummary })),
      ),
      AI_RATIONALE_TIMEOUT_MS,
      new Map<string, string>(),
    );

    await db.from("intent_recommendations").delete().eq("intent_id", intent_id);
    if (top.length > 0) {
      await db.from("intent_recommendations").insert(
        top.map((r) => ({
          intent_id,
          recommendation_type: r.recommendationType,
          target_id: r.targetId,
          title: r.title,
          subtitle: r.reasons[0] ?? null,
          image_url: r.imageUrl,
          score: r.score,
          reasons: r.reasons,
          ai_rationale: rationaleById.get(`${r.recommendationType}:${r.targetId}`) ?? null,
          signal_breakdown: r.signalBreakdown,
        })),
      );
    }

    return jsonResponse({
      recommendations: top.map((r) => ({
        recommendation_type: r.recommendationType,
        target_id: r.targetId,
        title: r.title,
        subtitle: r.reasons[0] ?? null,
        image_url: r.imageUrl,
        score: r.score,
        reasons: r.reasons,
        ai_rationale: rationaleById.get(`${r.recommendationType}:${r.targetId}`) ?? null,
        signal_breakdown: r.signalBreakdown,
      })),
    });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
