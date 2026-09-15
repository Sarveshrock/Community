// General technology news via each outlet's own public RSS feed — no key
// required, and (unlike a generic news API's free tier) nothing here
// restricts persisting the metadata we extract. Each feed is fetched
// independently so one broken/slow feed never takes the others down with
// it (spec section 21).

import { RawNewsItem } from "../utils/types.ts";
import { parseRssItems } from "../utils/rss.ts";
import { logSourceResult } from "../utils/logging.ts";

const FEEDS: { name: string; url: string }[] = [
  { name: "TechCrunch", url: "https://techcrunch.com/feed/" },
  { name: "The Verge", url: "https://www.theverge.com/rss/index.xml" },
  { name: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/index" },
  { name: "VentureBeat", url: "https://venturebeat.com/feed/" },
];

async function fetchFeed(name: string, url: string, perFeedLimit: number): Promise<RawNewsItem[]> {
  const res = await fetch(url, { headers: { "User-Agent": "community-app-tech-intel/1.0" } });
  if (!res.ok) throw new Error(`${name} RSS error: ${res.status}`);
  const xml = await res.text();
  const items = parseRssItems(xml, perFeedLimit);

  return items.map((i) => ({
    title: i.title,
    description: i.description,
    url: i.link,
    source: name,
    source_type: "news",
    published_at: i.pubDate ? new Date(i.pubDate).toISOString() : undefined,
    author: i.creator,
    image_url: i.imageUrl,
    tags: [],
    metadata: {},
  }));
}

export async function fetchTechNews(perFeedLimit: number): Promise<RawNewsItem[]> {
  const results = await Promise.allSettled(FEEDS.map((f) => fetchFeed(f.name, f.url, perFeedLimit)));

  const items: RawNewsItem[] = [];
  results.forEach((r, i) => {
    if (r.status === "fulfilled") {
      logSourceResult(FEEDS[i].name, r.value.length);
      items.push(...r.value);
    } else {
      logSourceResult(FEEDS[i].name, 0, r.reason);
    }
  });
  return items;
}
