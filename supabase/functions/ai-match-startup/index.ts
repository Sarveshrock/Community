// ai-match-startup — ranks open startup opportunities for the caller.

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

    const { data: opportunities, error } = await db
      .from("startup_opportunities")
      .select("id, title, description, role, startups(name, industry)")
      .eq("status", "open")
      .limit(200);
    if (error) throw error;

    const { skillNames, interestNames } = await getCallerSkillsAndInterests(callerId);
    const weights = await getWeights("startup");

    const targets = (opportunities ?? []).map((o: any) => ({
      id: o.id,
      requiredSkillNames: [] as string[],
      text: `${o.title} ${o.description ?? ""} ${o.role ?? ""} ${o.startups?.name ?? ""} ${o.startups?.industry ?? ""}`,
    }));

    const ranked = await rankTargetsWithAi(targets, skillNames, interestNames, weights, limit);
    await storeRecommendations(callerId, "startup", ranked);

    return jsonResponse({ recommendations: ranked });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
