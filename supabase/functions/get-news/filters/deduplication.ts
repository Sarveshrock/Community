// Cross-source deduplication (spec section 7). The same announcement often
// shows up on Hacker News, a tech outlet's RSS feed, and GitHub all at
// once — this collapses those into one row, keeping the highest-quality
// source's version. Cross-run dedup (the same story reappearing tomorrow)
// is handled separately at insert time via the unique content_hash index.

import { RawNewsItem } from "../utils/types.ts";
import { contentHash } from "../utils/normalization.ts";

/// Rough trust ranking used only to decide which duplicate to keep — not
/// the same as the `source_quality_score` ranking weight (see ranking.ts),
/// though they're intentionally similar.
export const SOURCE_QUALITY: Record<string, number> = {
  "arXiv": 95,
  "Semantic Scholar": 90,
  "GitHub": 90,
  "Hugging Face": 85,
  "Ars Technica": 80,
  "Hacker News": 80,
  "TechCrunch": 75,
  "The Verge": 75,
  "VentureBeat": 70,
  "Show HN": 65,
  "X": 55,
};

export function sourceQuality(source: string): number {
  return SOURCE_QUALITY[source] ?? 60;
}

export interface HashedItem extends RawNewsItem {
  content_hash: string;
}

export async function deduplicate(items: RawNewsItem[]): Promise<HashedItem[]> {
  const byHash = new Map<string, HashedItem>();

  for (const item of items) {
    const hash = await contentHash(item.title, item.url);
    const existing = byHash.get(hash);
    if (!existing || sourceQuality(item.source) > sourceQuality(existing.source)) {
      byHash.set(hash, { ...item, content_hash: hash });
    }
  }

  return Array.from(byHash.values());
}
