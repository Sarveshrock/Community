// Hugging Face Hub trending models — public API, no key required.

import { RawNewsItem } from "../utils/types.ts";

export async function fetchHuggingFaceTrending(limit: number): Promise<RawNewsItem[]> {
  const url = `https://huggingface.co/api/models?sort=trendingScore&direction=-1&limit=${Math.min(limit, 50)}`;
  const res = await fetch(url, { headers: { "User-Agent": "community-app-tech-intel" } });
  if (!res.ok) throw new Error(`Hugging Face API error: ${res.status}`);
  const items = (await res.json()) as any[];

  return items
    .filter((m) => m.id)
    .map((m) => ({
      title: m.id as string,
      description: m.pipeline_tag ? `Pipeline: ${m.pipeline_tag}` : undefined,
      url: `https://huggingface.co/${m.id}`,
      source: "Hugging Face",
      source_type: "github",
      published_at: (m.lastModified as string | undefined) ?? undefined,
      author: (m.id as string).split("/")[0],
      tags: ["AI", "Open Source"],
      metadata: { downloads: m.downloads ?? 0, likes: m.likes ?? 0, pipeline_tag: m.pipeline_tag ?? null },
    }));
}
