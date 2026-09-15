// ai-match-intent
// Scores candidates against a single Intent (spec-extension: reusable
// Matching Engine). Reuses the shared scoring helpers already used by
// ai-match-local rather than inventing new math; adds structured,
// explainable output (matched/missing/complementary skills, shared
// interests, availability compatibility, human-readable reasons) that the
// generic ai_recommendations table doesn't have room for, so results are
// written to the dedicated intent_matches table instead.
//
// On top of that deterministic scoring, the top few matches also get a real
// LLM-generated one-sentence rationale (see _shared/matchRationale.ts,
// reusing the same AiProvider abstraction — Anthropic/Gemini/Noop — as
// ai-match-job/ai-match-mentor/etc.). This is additive, not a replacement:
// with no AI_PROVIDER key configured, ai_rationale is simply null on every
// row and the deterministic reasons[]/score/score_breakdown are unaffected.
//
// Availability is the one signal that must never leak raw data: candidate
// schedules are read with the service-role client (bypassing RLS, which
// otherwise restricts user_availability to its owner) purely to compute a
// boolean overlap — actual time slots never appear in the response.

import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { userClient, requireUserId, serviceClient } from "../_shared/supabaseClient.ts";
import { weightedScore } from "../_shared/scoring.ts";
import { getAiProvider } from "../_shared/aiProvider.ts";
import { generateMatchRationales } from "../_shared/matchRationale.ts";
import { withTimeout } from "../_shared/timeout.ts";

// How many of the top-ranked matches get a real LLM-generated rationale —
// bounded on purpose: one batched call regardless of this number, but a
// smaller, focused set keeps the prompt (and judgment quality) tight. The
// other matches beyond this still have the deterministic reasons[] array.
const AI_RATIONALE_COUNT = 5;

// The AI call is a nice-to-have layer on top of scoring that's already
// complete without it — never let a slow/hung provider block the response.
const AI_RATIONALE_TIMEOUT_MS = 8000;

// Phase-1 default weights, hardcoded here rather than read from
// ai_scoring_weights (0017_ai.sql) because `intent` isn't a
// recommendation_type value yet. Adding it there later is a clean,
// backward-compatible follow-up, not a rewrite of this function.
const WEIGHTS = {
  skills_weight: 0.45,
  interests_weight: 0.2,
  goals_weight: 0,
  experience_weight: 0.15,
  availability_weight: 0.2,
  location_weight: 0,
  activity_weight: 0,
};

const EXPERIENCE_ORDER = ["beginner", "intermediate", "advanced", "expert"];

function intersect(a: string[], b: string[]): string[] {
  const setB = new Set(b.map((x) => x.toLowerCase()));
  const seen = new Set<string>();
  return a.filter((x) => {
    const key = x.toLowerCase();
    if (!setB.has(key) || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function subtract(a: string[], b: string[]): string[] {
  const setB = new Set(b.map((x) => x.toLowerCase()));
  return a.filter((x) => !setB.has(x.toLowerCase()));
}

function experienceScore(a: string, b: string): number {
  const ia = EXPERIENCE_ORDER.indexOf(a);
  const ib = EXPERIENCE_ORDER.indexOf(b);
  if (ia < 0 || ib < 0) return 0;
  const diff = Math.abs(ia - ib);
  if (diff === 0) return 1;
  if (diff === 1) return 0.5;
  return 0;
}

type Slot = { day_of_week: number; start_time: string; end_time: string };

function availabilityOverlap(a: Slot[], b: Slot[]): boolean | null {
  if (a.length === 0 || b.length === 0) return null;
  for (const sa of a) {
    for (const sb of b) {
      if (sa.day_of_week !== sb.day_of_week) continue;
      if (sa.start_time < sb.end_time && sb.start_time < sa.end_time) return true;
    }
  }
  return false;
}

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  try {
    const callerId = await requireUserId(req);
    const { intent_id } = await req.json();
    if (!intent_id) throw new Error("intent_id is required");

    // RLS on `intents` already restricts this select to the caller's own
    // intents or public ones — the explicit owner check below still rejects
    // scoring someone else's public intent from this endpoint.
    const asUser = userClient(req);
    const { data: intent, error: intentError } = await asUser
      .from("intents")
      .select("id, profile_id, experience_level")
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
    const neededSkills: string[] = (neededRows ?? [])
      .map((r: any) => r.skills?.name as string | undefined)
      .filter((x: string | undefined): x is string => !!x);

    const { data: callerInterestRows } = await db
      .from("profile_interests")
      .select("interests(name)")
      .eq("profile_id", callerId);
    const callerInterests: string[] = (callerInterestRows ?? [])
      .map((r: any) => r.interests?.name as string | undefined)
      .filter((x: string | undefined): x is string => !!x);

    const { data: callerAvailability } = await db
      .from("user_availability")
      .select("day_of_week, start_time, end_time")
      .eq("profile_id", callerId);

    const { data: blockRows } = await db
      .from("blocks")
      .select("blocker_id, blocked_id")
      .or(`blocker_id.eq.${callerId},blocked_id.eq.${callerId}`);
    const blockedIds = new Set(
      (blockRows ?? []).map((b: any) => (b.blocker_id === callerId ? b.blocked_id : b.blocker_id)),
    );

    const { data: candidateProfiles } = await db
      .from("profiles")
      .select("id, full_name, avatar_url, current_role, current_company, primary_user_type")
      .eq("professional_discoverable", true)
      .neq("id", callerId)
      .limit(200);
    const candidates = (candidateProfiles ?? []).filter((c: any) => !blockedIds.has(c.id));
    const candidateIds = candidates.map((c: any) => c.id);

    if (candidateIds.length === 0) {
      return jsonResponse({ matches: [] });
    }

    const { data: candidateSkillRows } = await db
      .from("profile_skills")
      .select("profile_id, experience_level, skills(name)")
      .in("profile_id", candidateIds);
    const { data: candidateInterestRows } = await db
      .from("profile_interests")
      .select("profile_id, interests(name)")
      .in("profile_id", candidateIds);
    const { data: candidateAvailabilityRows } = await db
      .from("user_availability")
      .select("profile_id, day_of_week, start_time, end_time")
      .in("profile_id", candidateIds);

    const skillsByProfile = new Map<string, string[]>();
    const experienceByProfile = new Map<string, string>();
    for (const row of candidateSkillRows ?? []) {
      const pid = (row as any).profile_id as string;
      const name = (row as any).skills?.name as string | undefined;
      if (name) skillsByProfile.set(pid, [...(skillsByProfile.get(pid) ?? []), name]);
      if ((row as any).experience_level) experienceByProfile.set(pid, (row as any).experience_level);
    }
    const interestsByProfile = new Map<string, string[]>();
    for (const row of candidateInterestRows ?? []) {
      const pid = (row as any).profile_id as string;
      const name = (row as any).interests?.name as string | undefined;
      if (name) interestsByProfile.set(pid, [...(interestsByProfile.get(pid) ?? []), name]);
    }
    const availabilityByProfile = new Map<string, Slot[]>();
    for (const row of candidateAvailabilityRows ?? []) {
      const pid = (row as any).profile_id as string;
      availabilityByProfile.set(pid, [...(availabilityByProfile.get(pid) ?? []), row as Slot]);
    }

    const results = candidates.map((c: any) => {
      const candidateSkills = skillsByProfile.get(c.id) ?? [];
      const candidateInterests = interestsByProfile.get(c.id) ?? [];
      const candidateAvailability = availabilityByProfile.get(c.id) ?? [];

      const matchedSkills = intersect(neededSkills, candidateSkills);
      const missingSkills = subtract(neededSkills, candidateSkills);
      const complementarySkills = subtract(candidateSkills, neededSkills).slice(0, 5);
      const sharedInterests = intersect(callerInterests, candidateInterests);
      const availabilityCompatible = availabilityOverlap(callerAvailability ?? [], candidateAvailability);
      const expScore = experienceScore(intent.experience_level, experienceByProfile.get(c.id) ?? "");

      const skillsScore = neededSkills.length === 0 ? 0 : matchedSkills.length / neededSkills.length;
      const interestsScore =
        callerInterests.length === 0 || candidateInterests.length === 0
          ? 0
          : sharedInterests.length / Math.min(callerInterests.length, candidateInterests.length);
      const availabilityScore = availabilityCompatible === true ? 1 : availabilityCompatible === false ? 0 : 0.5;

      const score = weightedScore(
        {
          skills: skillsScore,
          interests: interestsScore,
          goals: 0,
          experience: expScore,
          availability: availabilityScore,
          location: 0,
          activity: 0,
        },
        WEIGHTS,
      );

      const reasons: string[] = [];
      if (matchedSkills.length > 0) reasons.push(`They have the skills you need: ${matchedSkills.join(", ")}`);
      if (complementarySkills.length > 0) reasons.push(`They also bring: ${complementarySkills.slice(0, 3).join(", ")}`);
      if (sharedInterests.length > 0) reasons.push(`Shared interest in ${sharedInterests.slice(0, 2).join(" and ")}`);
      if (availabilityCompatible === true) reasons.push("Available at compatible times");
      if (expScore === 1) reasons.push("Similar experience level");
      if (reasons.length === 0) reasons.push("Broad match based on your profile.");

      return {
        intent_id,
        candidate_id: c.id,
        full_name: c.full_name,
        avatar_url: c.avatar_url,
        current_role: c.current_role,
        current_company: c.current_company,
        score,
        matched_skills: matchedSkills,
        missing_skills: missingSkills,
        complementary_skills: complementarySkills,
        shared_interests: sharedInterests,
        availability_compatible: availabilityCompatible,
        reasons,
        // Surfaced (not just used internally) so the client can render a
        // compatibility breakdown instead of one bare percentage.
        score_breakdown: {
          skills: skillsScore,
          interests: interestsScore,
          experience: expScore,
          availability: availabilityScore,
        },
      };
    });

    results.sort((a, b) => b.score - a.score);
    const top = results.slice(0, 20);

    // Real LLM-generated "why you matched" sentences for the top few, on top
    // of the deterministic `reasons[]` every match already has — one batched
    // call, bounded by AI_RATIONALE_TIMEOUT_MS, and a total no-op (empty map)
    // if no AI_PROVIDER key is configured. Never blocks or breaks matching.
    const rationaleTargets = top.slice(0, AI_RATIONALE_COUNT);
    const rationaleById = await withTimeout(
      generateMatchRationales(
        getAiProvider(),
        neededSkills.length > 0 ? `someone with skills: ${neededSkills.join(", ")}` : "a good match for their intent",
        rationaleTargets.map((r) => ({
          id: r.candidate_id,
          summary: r.reasons.join("; ") || "broad match based on profile",
        })),
      ),
      AI_RATIONALE_TIMEOUT_MS,
      new Map<string, string>(),
    );

    await db.from("intent_matches").delete().eq("intent_id", intent_id);
    if (top.length > 0) {
      await db.from("intent_matches").insert(
        top.map((r) => ({
          intent_id: r.intent_id,
          candidate_id: r.candidate_id,
          score: r.score,
          matched_skills: r.matched_skills,
          missing_skills: r.missing_skills,
          complementary_skills: r.complementary_skills,
          shared_interests: r.shared_interests,
          availability_compatible: r.availability_compatible,
          reasons: r.reasons,
          score_breakdown: r.score_breakdown,
          ai_rationale: rationaleById.get(r.candidate_id) ?? null,
          model_version: rationaleById.size > 0 ? "intent-ai-v1" : "intent-v1",
        })),
      );
    }

    return jsonResponse({ matches: top.map((r) => ({ ...r, ai_rationale: rationaleById.get(r.candidate_id) ?? null })) });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
