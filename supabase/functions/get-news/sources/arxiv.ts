// arXiv research papers via the public Atom API — no key required. Spans
// the CS categories most relevant to developers (spec section 10): AI, ML,
// NLP/LLM, Computer Vision, Robotics, Distributed Systems, Databases,
// Security, Programming Languages, Software Engineering.

import { RawNewsItem } from "../utils/types.ts";

const CATEGORIES = ["cs.AI", "cs.LG", "cs.CL", "cs.CV", "cs.RO", "cs.DC", "cs.DB", "cs.CR", "cs.PL", "cs.SE"];

const CATEGORY_TAG: Record<string, string> = {
  "cs.AI": "AI",
  "cs.LG": "Machine Learning",
  "cs.CL": "LLM",
  "cs.CV": "AI",
  "cs.RO": "Robotics",
  "cs.DC": "Infrastructure",
  "cs.DB": "Databases",
  "cs.CR": "Cybersecurity",
  "cs.PL": "Programming Languages",
  "cs.SE": "Developer Tools",
};

function parseEntries(xml: string): {
  id: string;
  title: string;
  summary: string;
  published: string;
  author: string;
  category: string;
}[] {
  const entries: ReturnType<typeof parseEntries> = [];
  const blocks = xml.split("<entry>").slice(1);
  for (const block of blocks) {
    const get = (tag: string) => {
      const m = block.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`));
      return m ? m[1].trim() : "";
    };
    const id = get("id");
    const title = get("title").replace(/\s+/g, " ");
    const summary = get("summary").replace(/\s+/g, " ").slice(0, 600);
    const published = get("published");
    const authorMatch = block.match(/<name>([\s\S]*?)<\/name>/);
    const categoryMatch = block.match(/<category term="([^"]+)"/);
    entries.push({
      id,
      title,
      summary,
      published,
      author: authorMatch ? authorMatch[1].trim() : "",
      category: categoryMatch ? categoryMatch[1] : "cs.AI",
    });
  }
  return entries;
}

export async function fetchArxiv(limit: number): Promise<RawNewsItem[]> {
  const query = CATEGORIES.map((c) => `cat:${c}`).join("+OR+");
  const url =
    `https://export.arxiv.org/api/query?search_query=${query}` +
    `&sortBy=submittedDate&sortOrder=descending&max_results=${Math.min(limit, 100)}`;

  const res = await fetch(url);
  if (!res.ok) throw new Error(`arXiv API error: ${res.status}`);
  const xml = await res.text();
  const entries = parseEntries(xml);

  return entries.map((e) => ({
    title: e.title,
    description: e.summary,
    url: e.id,
    source: "arXiv",
    source_type: "research",
    published_at: e.published || undefined,
    author: e.author || undefined,
    tags: ["Research", CATEGORY_TAG[e.category] ?? "AI"],
    metadata: { arxiv_category: e.category },
  }));
}
