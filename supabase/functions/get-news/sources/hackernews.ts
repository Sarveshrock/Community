// Hacker News via the public Algolia API — no key required. Community
// signal (points/comments) feeds importance scoring downstream.

import { RawNewsItem } from "../utils/types.ts";

export async function fetchHackerNews(windowHours: number, limit: number): Promise<RawNewsItem[]> {
  const sinceEpoch = Math.floor((Date.now() - windowHours * 3_600_000) / 1000);
  const url =
    `https://hn.algolia.com/api/v1/search_by_date?tags=story` +
    `&numericFilters=created_at_i>${sinceEpoch},points>=15` +
    `&hitsPerPage=${Math.min(limit, 100)}`;

  const res = await fetch(url);
  if (!res.ok) throw new Error(`Hacker News API error: ${res.status}`);
  const json = await res.json();

  return ((json.hits ?? []) as any[])
    .filter((h) => h.url && h.title)
    .map((h) => ({
      title: h.title as string,
      description: undefined,
      url: h.url as string,
      source: "Hacker News",
      source_type: "community",
      published_at: h.created_at as string | undefined,
      author: h.author as string | undefined,
      tags: [],
      metadata: { points: h.points ?? 0, num_comments: h.num_comments ?? 0, hn_id: h.objectID },
    }));
}
