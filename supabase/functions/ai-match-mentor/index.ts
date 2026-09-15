// ai-match-mentor — ranks available mentors for the caller.

import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { requireUserId, serviceClient } from "../_shared/supabaseClient.ts";
import { getCallerSkillsAndInterests, getWeights, rankTargetsWithAi, storeRecommendations } from "../_shared/genericMatch.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;
  try {
    const callerId = await requireUserId(req);
    const { limit = 20 } = await req.json().catch(() => ({}));
    const db = serviceClient();

    const { data: mentors, error } = await db
      .from("mentor_profiles")
      .select("profile_id, expertise, topics, bio")
      .eq("available", true)
      .neq("profile_id", callerId)
      .limit(200);
    if (error) throw error;

    const { skillNames, interestNames } = await getCallerSkillsAndInterests(callerId);
    const weights = await getWeights("mentor");

    const targets = (mentors ?? []).map((m: any) => ({
      id: m.profile_id,
      requiredSkillNames: (m.expertise ?? []) as string[],
      text: `${(m.topics ?? []).join(" ")} ${m.bio ?? ""}`,
    }));

    const ranked = await rankTargetsWithAi(targets, skillNames, interestNames, weights, limit);
    await storeRecommendations(callerId, "mentor", ranked);

    return jsonResponse({ recommendations: ranked });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
