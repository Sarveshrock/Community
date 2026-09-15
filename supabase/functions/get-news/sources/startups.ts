// Startup/product-launch signal via Hacker News's "Show HN" tag (public
// Algolia API, no key). Deliberately not a generic business-news source —
// Show HN posts are self-selected product/project launches from builders,
// which keeps this on-topic without a paid Crunchbase-style dependency.

import { RawNewsItem } from "../utils/types.ts";

export async function fetchStartupLaunches(windowHours: number, limit: number): Promise<RawNewsItem[]> {
  const sinceEpoch = Math.floor((Date.now() - windowHours * 3_600_000) / 1000);
  const url =
    `https://hn.algolia.com/api/v1/search_by_date?tags=show_hn` +
    `&numericFilters=created_at_i>${sinceEpoch},points>=5` +
    `&hitsPerPage=${Math.min(limit, 100)}`;

  const res = await fetch(url);
  if (!res.ok) throw new Error(`Show HN API error: ${res.status}`);
  const json = await res.json();

  return ((json.hits ?? []) as any[])
    .filter((h) => h.title)
    .map((h) => ({
      title: (h.title as string).replace(/^Show HN:\s*/i, ""),
      description: h.story_text ?? undefined,
      url: (h.url as string) || `https://news.ycombinator.com/item?id=${h.objectID}`,
      source: "Show HN",
      source_type: "startup",
      published_at: h.created_at as string | undefined,
      author: h.author as string | undefined,
      tags: ["Startups"],
      metadata: { points: h.points ?? 0, num_comments: h.num_comments ?? 0, hn_id: h.objectID },
    }));
}
