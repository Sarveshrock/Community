// The shape every source module normalizes its results into, before
// dedup/filter/rank ever sees them.

export interface RawNewsItem {
  title: string;
  description?: string;
  url: string;
  source: string; // human-readable, e.g. "Hacker News", "GitHub"
  source_type: string; // "community" | "github" | "research" | "news" | "startup" | "social"
  published_at?: string;
  author?: string;
  image_url?: string;
  tags?: string[];
  metadata?: Record<string, unknown>;
}
