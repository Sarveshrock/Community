// ai-match-team — ranks open hackathon team requirements for the caller.

import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { requireUserId, serviceClient } from "../_shared/supabaseClient.ts";
import { getCallerSkillsAndInterests, getWeights, rankTargetsWithAi, storeRecommendations } from "../_shared/genericMatch.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;
  try {
    const callerId = await requireUserId(req);
    const { hackathon_id, limit = 20 } = await req.json().catch(() => ({}));
    const db = serviceClient();

    let query = db
      .from("hackathon_team_requirements")
      .select("id, team_name, description, hackathon_team_required_skills(skills(normalized_name))")
      .eq("status", "open")
      .limit(200);
    if (hackathon_id) query = query.eq("hackathon_id", hackathon_id);
    const { data: teams, error } = await query;
    if (error) throw error;

    const { skillNames, interestNames } = await getCallerSkillsAndInterests(callerId);
    const weights = await getWeights("hackathon_team");

    const targets = (teams ?? []).map((t: any) => ({
      id: t.id,
      requiredSkillNames: (t.hackathon_team_required_skills ?? []).map((s: any) => s.skills?.normalized_name).filter(Boolean),
      text: `${t.team_name} ${t.description ?? ""}`,
    }));

    const ranked = await rankTargetsWithAi(targets, skillNames, interestNames, weights, limit);
    await storeRecommendations(callerId, "hackathon_team", ranked);

    return jsonResponse({ recommendations: ranked });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
