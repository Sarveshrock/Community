// natural-language-search
// Converts a free-text query into structured filters (spec section 46).
// Uses lightweight rule-based parsing by default; if AI_PROVIDER is
// configured, delegates parsing to it for better coverage. Never expose
// private location data in the response.

import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { requireUserId, serviceClient } from "../_shared/supabaseClient.ts";
import { getAiProvider, stripCodeFence } from "../_shared/aiProvider.ts";

interface ParsedFilters {
  intent: "people" | "local" | "jobs" | "projects" | "hackathons" | "unknown";
  skill?: string;
  city?: string;
  min_experience_months?: number;
  interest?: string;
  activity?: string;
}

function ruleBasedParse(query: string): ParsedFilters {
  const q = query.toLowerCase();
  const filters: ParsedFilters = { intent: "unknown" };

  if (/nearby|near me|local|coffee|walk|meet(up)?/.test(q)) {
    filters.intent = "local";
  } else if (/job|hiring|role|position/.test(q)) {
    filters.intent = "jobs";
  } else if (/project|collaborat/.test(q)) {
    filters.intent = "projects";
  } else if (/hackathon|team/.test(q)) {
    filters.intent = "hackathons";
  } else {
    filters.intent = "people";
  }

  const expMatch = q.match(/(\d+)\+?\s*(years?|yrs?)/);
  if (expMatch) filters.min_experience_months = parseInt(expMatch[1], 10) * 12;

  const inMatch = q.match(/in ([a-z\s]+?)(?:with|\.|$)/);
  if (inMatch) filters.city = inMatch[1].trim();

  const knownSkills = ["flutter", "react", "python", "node", "dart", "go", "rust", "ai", "machine learning"];
  const foundSkill = knownSkills.find((s) => q.includes(s));
  if (foundSkill) filters.skill = foundSkill;

  const knownActivities = ["coffee", "walk", "dinner", "gaming", "movie"];
  const foundActivity = knownActivities.find((a) => q.includes(a));
  if (foundActivity) filters.activity = foundActivity;

  return filters;
}

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  try {
    const callerId = await requireUserId(req);
    const { query } = await req.json();
    if (!query || typeof query !== "string") throw new Error("query is required");

    const ai = getAiProvider();
    let filters: ParsedFilters;
    const aiText = await ai.generateText(
      `Extract search filters as JSON only (no prose) with keys intent(one of people,local,jobs,projects,hackathons), skill, city, min_experience_months, interest, activity from: "${query}"`,
      200,
    );
    try {
      filters = aiText ? JSON.parse(stripCodeFence(aiText)) : ruleBasedParse(query);
    } catch {
      filters = ruleBasedParse(query);
    }

    const db = serviceClient();
    let results: unknown[] = [];

    if (filters.intent === "people") {
      let q = db.from("profiles").select("id, full_name, city, current_role, current_company").eq("professional_discoverable", true).neq("id", callerId).limit(20);
      if (filters.city) q = q.ilike("city", `%${filters.city}%`);
      if (filters.min_experience_months) q = q.gte("total_it_experience_months", filters.min_experience_months);
      const { data } = await q;
      results = data ?? [];
    } else if (filters.intent === "jobs") {
      let q = db.from("jobs").select("id, title, company_name, location, work_mode").eq("status", "open").limit(20);
      if (filters.city) q = q.ilike("location", `%${filters.city}%`);
      const { data } = await q;
      results = data ?? [];
    } else if (filters.intent === "projects") {
      const { data } = await db.from("projects").select("id, title, description, category").eq("status", "open").limit(20);
      results = data ?? [];
    } else if (filters.intent === "hackathons") {
      const { data } = await db.from("hackathons").select("id, name, event_date").limit(20);
      results = data ?? [];
    } else if (filters.intent === "local") {
      // Delegated to get_local_candidates via the caller's own session so
      // RLS/privacy rules apply; the client should call ai-match-local
      // directly for this intent. We just echo the parsed filters here.
      results = [];
    }

    return jsonResponse({ filters, results });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
