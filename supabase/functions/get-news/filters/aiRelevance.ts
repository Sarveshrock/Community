// Optional AI refinement for borderline items only (spec section 12):
// cheap rule-based scoring runs on everything; this only fires for items
// whose rule-based score landed near the relevance threshold (genuinely
// ambiguous), and only when an AI provider is configured. Any failure
// falls back to the rule-based score — the pipeline never depends on this.

import { AiProvider, isAiConfigured, stripCodeFence } from "../../_shared/aiProvider.ts";
import { RawNewsItem } from "../utils/types.ts";
import { clampScore } from "../utils/normalization.ts";

const BORDERLINE_BAND = 15;
const MAX_BATCH = 15;

export async function refineBorderlineRelevance(
  ai: AiProvider,
  threshold: number,
  scored: { item: RawNewsItem; score: number }[],
): Promise<{ item: RawNewsItem; score: number }[]> {
  if (!isAiConfigured()) return scored;

  const borderline = scored
    .filter((s) => Math.abs(s.score - threshold) <= BORDERLINE_BAND)
    .slice(0, MAX_BATCH);
  if (borderline.length === 0) return scored;

  const prompt =
    "You are filtering a technology-intelligence feed. For each item below, score 0-100 how directly " +
    "relevant it is to software development, AI/ML, research, developer tools, startups building tech " +
    "products, or technology infrastructure. Generic business/politics/entertainment/sports content — even " +
    "if a tech company is mentioned in passing — should score low. Respond ONLY with a JSON array like " +
    '[{"i":0,"score":72}].\n\n' +
    borderline.map((b, i) => `i=${i}: ${b.item.title} — ${(b.item.description ?? "").slice(0, 200)}`).join("\n");

  try {
    const text = await ai.generateText(prompt, 800);
    const parsed = JSON.parse(stripCodeFence(text)) as { i: number; score: number }[];
    const byIndex = new Map(parsed.map((p) => [p.i, p.score]));

    const refined = [...scored];
    borderline.forEach((b, i) => {
      const aiScore = byIndex.get(i);
      if (aiScore === undefined) return;
      const originalIndex = refined.findIndex((r) => r.item === b.item);
      if (originalIndex === -1) return;
      // Blend rather than fully override — the rule-based pass still
      // anchors the result even when the AI's read differs.
      refined[originalIndex] = { item: b.item, score: clampScore(b.score * 0.4 + aiScore * 0.6) };
    });
    return refined;
  } catch {
    // AI classification failed/unparseable — rule-based scores stand.
    return scored;
  }
}
