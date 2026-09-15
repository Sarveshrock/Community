// ai-match-local
// Local matching prioritizes shared interests/activities/availability over
// professional signals (spec section 44). Never touches raw coordinates —
// candidate retrieval is delegated to the privacy-safe get_local_candidates()
// database function.

import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { userClient, requireUserId, serviceClient } from "../_shared/supabaseClient.ts";
import { jaccard, reasonFromComponents, weightedScore } from "../_shared/scoring.ts";

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  try {
    const callerId = await requireUserId(req);
    const { limit = 20 } = await req.json().catch(() => ({}));

    // Use the caller's own JWT so RLS/SECURITY DEFINER checks inside
    // get_local_candidates() run as the actual user, not the service role.
    const asUser = userClient(req);
    const { data: candidates, error } = await asUser.rpc("get_local_candidates", {
      result_limit: Math.min(limit, 50),
    });
    if (error) throw error;

    const db = serviceClient();
    const { data: prefs } = await db
      .from("local_preferences")
      .select("activity_preferences, interest_preferences")
      .eq("profile_id", callerId)
      .single();
    const { data: weightsRow } = await db
      .from("ai_scoring_weights")
      .select("*")
      .eq("recommendation_type", "local_person")
      .single();

    const weights = weightsRow ?? {
      skills_weight: 0.05,
      interests_weight: 0.35,
      goals_weight: 0.1,
      experience_weight: 0,
      availability_weight: 0.25,
      location_weight: 0.2,
      activity_weight: 0.05,
    };

    const results = (candidates ?? []).map((c: any) => {
      const bio = (c.bio ?? "").toLowerCase();
      const interestOverlap = jaccard(prefs?.interest_preferences ?? [], bio.split(/\W+/));
      const activityOverlap = jaccard(prefs?.activity_preferences ?? [], bio.split(/\W+/));
      const locationScore = c.approximate_distance_bucket === "<1 km" || c.approximate_distance_bucket === "1-3 km" ? 1 : 0.5;

      const components = {
        skills: 0,
        interests: interestOverlap,
        goals: 0,
        experience: 0,
        availability: 0.6,
        location: locationScore,
        activity: activityOverlap,
      };

      return {
        candidate_id: c.profile_id,
        display_name: c.display_name,
        avatar_url: c.avatar_url,
        distance: c.approximate_distance_bucket,
        city: c.city,
        area: c.area,
        score: weightedScore(components, weights),
        reason: reasonFromComponents(components),
      };
    });

    results.sort((a, b) => b.score - a.score);

    return jsonResponse({ recommendations: results.slice(0, limit) });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
