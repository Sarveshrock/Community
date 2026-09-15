// ai-match-people
// Flutter -> Edge Function -> candidate retrieval -> deterministic scoring
// -> optional semantic ranking -> privacy filtering -> recommendations.
//
// Deploy: supabase functions deploy ai-match-people
// Secrets required: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY
// (AI_PROVIDER / AI_PROVIDER_API_KEY optional, for semantic re-ranking)

import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { requireUserId, serviceClient } from "../_shared/supabaseClient.ts";
import { jaccard, reasonFromComponents, weightedScore } from "../_shared/scoring.ts";
import { getAiProvider, matchModelVersion } from "../_shared/aiProvider.ts";
import { applySemanticReranking, Scored } from "../_shared/semanticRerank.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  try {
    const callerId = await requireUserId(req);
    const { limit = 20, userType, maxExperienceMonths } = await req.json().catch(() => ({}));
    const db = serviceClient();

    const { data: caller, error: callerErr } = await db
      .from("profiles")
      .select(
        "id, city, career_goals, availability, total_it_experience_months, is_open_to_mentorship",
      )
      .eq("id", callerId)
      .single();
    if (callerErr || !caller) throw new Error("caller profile not found");

    const [{ data: callerSkills }, { data: callerInterests }, { data: weightsRow }] =
      await Promise.all([
        db.from("profile_skills").select("skill_id, skills(normalized_name)").eq("profile_id", callerId),
        db.from("profile_interests").select("interest_id, interests(normalized_name)").eq("profile_id", callerId),
        db.from("ai_scoring_weights").select("*").eq("recommendation_type", "person").single(),
      ]);

    const weights = weightsRow ?? {
      skills_weight: 0.35,
      interests_weight: 0.2,
      goals_weight: 0.15,
      experience_weight: 0.1,
      availability_weight: 0.1,
      location_weight: 0.05,
      activity_weight: 0.05,
    };

    const callerSkillNames = (callerSkills ?? []).map((s: any) => s.skills?.normalized_name).filter(Boolean);
    const callerInterestNames = (callerInterests ?? []).map((s: any) => s.interests?.normalized_name).filter(Boolean);

    // Candidate retrieval: discoverable profiles, excluding self / blocked /
    // already-connected. Privacy filtering happens at the query level.
    const { data: blocked } = await db
      .from("blocks")
      .select("blocker_id, blocked_id")
      .or(`blocker_id.eq.${callerId},blocked_id.eq.${callerId}`);
    const blockedIds = new Set(
      (blocked ?? []).flatMap((b: any) => [b.blocker_id, b.blocked_id]).filter((id: string) => id !== callerId),
    );

    // `userType`/`maxExperienceMonths` scope the candidate pool itself
    // (People screen's category chips — "Fresher" isn't a real `user_type`
    // enum value, it's ~0 months of experience) so a recommendation score
    // is always computed within the selected category, not filtered out of
    // a global top-N after the fact.
    let candidateQuery = db
      .from("profiles")
      .select(
        "id, full_name, avatar_url, current_role, current_company, primary_user_type, city, career_goals, availability, total_it_experience_months, updated_at",
      )
      .eq("professional_discoverable", true)
      .neq("id", callerId);
    if (typeof userType === "string" && userType.length > 0) {
      candidateQuery = candidateQuery.eq("primary_user_type", userType);
    }
    if (typeof maxExperienceMonths === "number") {
      candidateQuery = candidateQuery.lte("total_it_experience_months", maxExperienceMonths);
    }
    const { data: candidates, error: candErr } = await candidateQuery.limit(200);
    if (candErr) throw candErr;

    const filtered = (candidates ?? []).filter((c) => !blockedIds.has(c.id));

    const { data: allSkills } = await db
      .from("profile_skills")
      .select("profile_id, skills(normalized_name)")
      .in("profile_id", filtered.map((c) => c.id));
    const { data: allInterests } = await db
      .from("profile_interests")
      .select("profile_id, interests(normalized_name)")
      .in("profile_id", filtered.map((c) => c.id));

    const skillsByProfile = new Map<string, string[]>();
    for (const row of allSkills ?? []) {
      const name = (row as any).skills?.normalized_name;
      if (!name) continue;
      const list = skillsByProfile.get((row as any).profile_id) ?? [];
      list.push(name);
      skillsByProfile.set((row as any).profile_id, list);
    }
    const interestsByProfile = new Map<string, string[]>();
    for (const row of allInterests ?? []) {
      const name = (row as any).interests?.normalized_name;
      if (!name) continue;
      const list = interestsByProfile.get((row as any).profile_id) ?? [];
      list.push(name);
      interestsByProfile.set((row as any).profile_id, list);
    }

    const now = Date.now();
    const scored: Scored<typeof filtered[number]>[] = filtered.map((c) => {
      const skillsScore = jaccard(callerSkillNames, skillsByProfile.get(c.id) ?? []);
      const interestsScore = jaccard(callerInterestNames, interestsByProfile.get(c.id) ?? []);
      const goalsScore = caller.career_goals && c.career_goals
        ? jaccard(caller.career_goals.split(/\W+/), c.career_goals.split(/\W+/))
        : 0;
      const expDiff = Math.abs((caller.total_it_experience_months ?? 0) - (c.total_it_experience_months ?? 0));
      const experienceScore = Math.max(0, 1 - expDiff / 120);
      const availabilityScore = caller.availability && c.availability && caller.availability === c.availability ? 1 : 0.3;
      const locationScore = caller.city && c.city && caller.city.toLowerCase() === c.city.toLowerCase() ? 1 : 0;
      const daysSinceUpdate = (now - new Date(c.updated_at).getTime()) / 86_400_000;
      const activityScore = Math.max(0, 1 - daysSinceUpdate / 30);

      const components = {
        skills: skillsScore,
        interests: interestsScore,
        goals: goalsScore,
        experience: experienceScore,
        availability: availabilityScore,
        location: locationScore,
        activity: activityScore,
      };

      return {
        item: c,
        id: c.id,
        score: weightedScore(components, weights),
        reason: reasonFromComponents(components),
      };
    });

    scored.sort((a, b) => b.score - a.score);

    // Optional semantic re-ranking pass (spec section 43): widen the
    // deterministic pool a bit so the AI has real signal to reorder within,
    // then trim to `limit`. No-op unless AI_PROVIDER is configured.
    const ai = getAiProvider();
    const pool = scored.slice(0, Math.max(limit * 2, 20));
    const reranked = await applySemanticReranking(
      ai,
      `A person interested in: ${callerInterestNames.join(", ") || "general networking"}. ` +
        `Skills: ${callerSkillNames.join(", ") || "none listed"}. Goals: ${caller.career_goals ?? "not specified"}.`,
      pool,
      (c) =>
        `${c.full_name}, ${c.city ?? "unknown city"}, goals: ${c.career_goals ?? "n/a"}, ` +
        `skills: ${(skillsByProfile.get(c.id) ?? []).join(", ")}, interests: ${(interestsByProfile.get(c.id) ?? []).join(", ")}`,
    );
    const top = reranked.slice(0, limit);

    const rows = top.map((t) => ({
      profile_id: callerId,
      candidate_id: t.item.id,
      recommendation_type: "person",
      score: t.score,
      reason: t.reason,
      model_version: matchModelVersion(),
    }));

    if (rows.length > 0) {
      await db.from("ai_recommendations").insert(rows);
    }

    return jsonResponse({
      recommendations: top.map((t) => ({
        candidate_id: t.item.id,
        full_name: t.item.full_name,
        current_role: t.item.current_role,
        current_company: t.item.current_company,
        city: t.item.city,
        score: t.score,
        reason: t.reason,
      })),
    });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
