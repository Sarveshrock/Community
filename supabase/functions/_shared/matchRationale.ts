// Generates a short, natural-language rationale sentence per candidate,
// reusing the same AiProvider abstraction (and NoopProvider fallback) as
// semanticRerank.ts — but a distinct helper rather than forcing callers
// through genericMatch.ts's generic jaccard scoring, since match functions
// like ai-match-intent already compute better, domain-specific deterministic
// scores/components of their own. This only adds the human-readable
// explanation on top; it never decides ranking or score, and the LLM is
// never given anything to work with beyond the structured facts the caller
// already computed — it cannot invent skills, names, or relationships not
// present in `summary`.
//
// One batched LLM call for all candidates (not one call per candidate) —
// keeps latency and cost bounded regardless of how many top matches/
// recommendations are requested. Two thin public entry points
// (person-match rationale, cross-entity recommendation rationale) share one
// prompt-and-parse implementation.

import { AiProvider, isAiConfigured, stripCodeFence } from "./aiProvider.ts";

export interface RationaleCandidate {
  id: string;
  /// A short plain-text summary of *why* this candidate scored well —
  /// matched skills, shared interests, availability, etc. — for the LLM to
  /// turn into a warm, specific sentence. Never raw PII beyond what the
  /// caller already intends to show the requester.
  summary: string;
}

async function generateRationalesFromPrompt(ai: AiProvider, prompt: string): Promise<Map<string, string>> {
  try {
    const text = await ai.generateText(prompt, 1024);
    const parsed = JSON.parse(stripCodeFence(text)) as { id: string; rationale: string }[];
    const map = new Map<string, string>();
    for (const p of parsed) {
      if (p?.id && typeof p.rationale === "string" && p.rationale.trim()) {
        map.set(p.id, p.rationale.trim());
      }
    }
    return map;
  } catch {
    // AI provider errored, timed out, or returned unparseable output — the
    // deterministic reasons[] array is always still there for the UI.
    return new Map();
  }
}

/// Returns a map of candidate id -> one-sentence rationale. Empty map (never
/// throws) if no AI provider is configured or the call/parse fails — callers
/// already have deterministic reasons[] to fall back to, so a missing
/// rationale must never break matching.
export async function generateMatchRationales(
  ai: AiProvider,
  queryText: string,
  candidates: RationaleCandidate[],
): Promise<Map<string, string>> {
  if (!isAiConfigured() || candidates.length === 0) return new Map();

  const prompt =
    `A user is looking for: "${queryText}"\n\n` +
    `Here are their top candidate matches, each with the factual signals behind their score:\n\n` +
    candidates.map((c) => `id=${c.id}: ${c.summary}`).join("\n") +
    `\n\nFor each candidate, write ONE warm, specific sentence (max 30 words) explaining why they're a good match, ` +
    `using only the facts given — never invent skills, names, or details not listed above. ` +
    `Respond ONLY with a JSON array like [{"id":"...","rationale":"..."}].`;

  return generateRationalesFromPrompt(ai, prompt);
}

/// Same contract as [generateMatchRationales], for cross-entity
/// recommendations (a community/event/project/post surfaced because of a
/// compatible person) rather than the person match itself — a "why am I
/// seeing this?" sentence grounded only in the given fact summary.
export async function generateRecommendationRationales(
  ai: AiProvider,
  queryText: string,
  candidates: RationaleCandidate[],
): Promise<Map<string, string>> {
  if (!isAiConfigured() || candidates.length === 0) return new Map();

  const prompt =
    `A user is looking for: "${queryText}"\n\n` +
    `Here are recommendations (communities, events, projects, or posts) surfaced because of people ` +
    `compatible with that goal, each with the factual signals behind it:\n\n` +
    candidates.map((c) => `id=${c.id}: ${c.summary}`).join("\n") +
    `\n\nFor each, write ONE concise sentence (max 30 words) explaining why it's being recommended, ` +
    `using only the facts given — never invent people, numbers, or details not listed above. ` +
    `Respond ONLY with a JSON array like [{"id":"...","rationale":"..."}].`;

  return generateRationalesFromPrompt(ai, prompt);
}
