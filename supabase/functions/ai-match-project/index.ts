// ai-match-project — ranks open projects against the caller's skills/interests.

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

    const { data: projects, error } = await db
      .from("projects")
      .select("id, title, description, category, project_required_skills(skills(normalized_name))")
      .eq("status", "open")
      .limit(200);
    if (error) throw error;

    const { skillNames, interestNames } = await getCallerSkillsAndInterests(callerId);
    const weights = await getWeights("project");

    const targets = (projects ?? []).map((p: any) => ({
      id: p.id,
      requiredSkillNames: (p.project_required_skills ?? []).map((s: any) => s.skills?.normalized_name).filter(Boolean),
      text: `${p.title} ${p.description ?? ""} ${p.category ?? ""}`,
    }));

    const ranked = await rankTargetsWithAi(targets, skillNames, interestNames, weights, limit);
    await storeRecommendations(callerId, "project", ranked);

    return jsonResponse({ recommendations: ranked });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
