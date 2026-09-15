// Minimal RSS 2.0 / Atom feed item parser — no external XML library
// dependency, matching this project's existing hand-rolled arXiv Atom
// parsing. Good enough for the well-formed feeds this pipeline targets;
// not a general XML parser. Handles both formats because real-world tech
// outlets mix them (e.g. The Verge publishes Atom, not RSS 2.0).

export interface RssItem {
  title: string;
  link: string;
  description?: string;
  pubDate?: string;
  creator?: string;
  imageUrl?: string;
}

function unwrapCdata(s: string): string {
  const m = s.match(/^<!\[CDATA\[([\s\S]*?)\]\]>$/);
  return (m ? m[1] : s).trim();
}

function decodeEntities(s: string): string {
  return s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'");
}

function stripTags(s: string): string {
  return s.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
}

function getTag(block: string, tag: string): string | undefined {
  const m = block.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, "i"));
  return m ? decodeEntities(unwrapCdata(m[1].trim())) : undefined;
}

function getFirst(block: string, tags: string[]): string | undefined {
  for (const t of tags) {
    const v = getTag(block, t);
    if (v) return v;
  }
  return undefined;
}

function parseBlock(block: string): RssItem | null {
  const title = getFirst(block, ["title"]);

  // RSS: <link>https://...</link>. Atom: <link href="https://..."/>
  // (self-closing, no inner text) — try the RSS form first, then href.
  const link = getFirst(block, ["link"]) || block.match(/<link[^>]*href="([^"]+)"[^>]*\/?>/i)?.[1];
  if (!title || !link) return null;

  let imageUrl: string | undefined;
  const enclosure = block.match(/<enclosure[^>]*url="([^"]+)"[^>]*type="image/i);
  const mediaContent = block.match(/<media:content[^>]*url="([^"]+)"/i);
  const mediaThumb = block.match(/<media:thumbnail[^>]*url="([^"]+)"/i);
  imageUrl = enclosure?.[1] ?? mediaContent?.[1] ?? mediaThumb?.[1];

  const rawDescription = getFirst(block, ["description", "summary", "content"]);
  if (!imageUrl && rawDescription) {
    imageUrl = rawDescription.match(/<img[^>]*src="([^"]+)"/i)?.[1];
  }

  const rawAuthor = getFirst(block, ["dc:creator", "author"]);

  return {
    title: stripTags(title),
    link: link.trim(),
    description: rawDescription ? stripTags(rawDescription).slice(0, 600) : undefined,
    pubDate: getFirst(block, ["pubDate", "dc:date", "published", "updated"]),
    creator: rawAuthor ? stripTags(rawAuthor) : undefined,
    imageUrl,
  };
}

export function parseRssItems(xml: string, limit = 30): RssItem[] {
  const tag = /<entry[\s>]/i.test(xml) && !/<item[\s>]/i.test(xml) ? "entry" : "item";
  const splitter = new RegExp(`<${tag}[\\s>]`, "i");
  const closer = new RegExp(`</${tag}>`, "i");

  const blocks = xml.split(splitter).slice(1);
  const items: RssItem[] = [];
  for (const rawBlock of blocks.slice(0, limit)) {
    const block = `<${tag}>` + rawBlock.split(closer)[0];
    const parsed = parseBlock(block);
    if (parsed) items.push(parsed);
  }
  return items;
}
