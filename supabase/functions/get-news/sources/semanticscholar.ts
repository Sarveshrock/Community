// Semantic Scholar Graph API — free, keyless (SEMANTIC_SCHOLAR_API_KEY is
// optional and only raises the rate limit). Complements arXiv with
// citation counts as an importance signal and broader venue coverage.

import { RawNewsItem } from "../utils/types.ts";

const QUERY =
  "artificial intelligence OR machine learning OR large language model OR " +
  "distributed systems OR software engineering OR computer vision OR robotics OR cybersecurity";

export async function fetchSemanticScholar(limit: number): Promise<RawNewsItem[]> {
  const apiKey = Deno.env.get("SEMANTIC_SCHOLAR_API_KEY");
  const url =
    `https://api.semanticscholar.org/graph/v1/paper/search/bulk` +
    `?query=${encodeURIComponent(QUERY)}` +
    `&fields=title,abstract,url,publicationDate,authors,citationCount,venue` +
    `&sort=publicationDate:desc` +
    `&fieldsOfStudy=Computer Science`;

  const res = await fetch(url, {
    headers: apiKey ? { "x-api-key": apiKey } : {},
  });
  if (!res.ok) throw new Error(`Semantic Scholar API error: ${res.status}`);
  const json = await res.json();

  const papers = ((json.data ?? []) as any[]).slice(0, limit);
  return papers
    .filter((p) => p.title && p.url)
    .map((p) => ({
      title: p.title as string,
      description: (p.abstract as string | null)?.slice(0, 600) ?? undefined,
      url: p.url as string,
      source: "Semantic Scholar",
      source_type: "research",
      published_at: p.publicationDate ? `${p.publicationDate}T00:00:00Z` : undefined,
      author: (p.authors ?? []).map((a: any) => a.name).slice(0, 3).join(", ") || undefined,
      tags: ["Research"],
      metadata: { citation_count: p.citationCount ?? 0, venue: p.venue ?? null },
    }));
}
