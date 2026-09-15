// Optional X/Twitter integration — entirely inert unless X_BEARER_TOKEN is
// configured (spec: "must not be a hard dependency"). No scraping: this
// only calls X's own official API v2 recent-search endpoint with a Bearer
// token you provide. Never called at all when unconfigured — the pipeline
// just proceeds with its other sources.

import { RawNewsItem } from "../utils/types.ts";

const QUERY = '(AI OR "open source" OR "machine learning" OR framework OR "developer tool" OR launch) -is:retweet lang:en';

export function isXConfigured(): boolean {
  return !!Deno.env.get("X_BEARER_TOKEN");
}

export async function fetchXPosts(limit: number): Promise<RawNewsItem[]> {
  const token = Deno.env.get("X_BEARER_TOKEN");
  if (!token) return [];

  const url =
    `https://api.twitter.com/2/tweets/search/recent?query=${encodeURIComponent(QUERY)}` +
    `&max_results=${Math.max(10, Math.min(limit, 100))}` +
    `&tweet.fields=created_at,public_metrics,author_id` +
    `&expansions=author_id&user.fields=username,name`;

  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`X API error: ${res.status}`);
  const json = await res.json();

  const users = new Map<string, any>((json.includes?.users ?? []).map((u: any) => [u.id, u]));
  const tweets = (json.data ?? []) as any[];

  return tweets
    .filter((t) => t.text)
    .map((t) => {
      const user = users.get(t.author_id);
      const handle = user?.username ?? "twitter";
      return {
        title: (t.text as string).slice(0, 200),
        description: undefined,
        url: `https://x.com/${handle}/status/${t.id}`,
        source: "X",
        source_type: "social",
        published_at: t.created_at as string | undefined,
        author: user?.name ?? handle,
        tags: [],
        metadata: { public_metrics: t.public_metrics ?? {} },
      };
    });
}
