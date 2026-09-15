// Shared normalization helpers used by every source and by deduplication.

/// Strips tracking params, fragment, trailing slash, and lowercases the
/// host so the same article linked from two sources canonicalizes to one
/// URL (spec section 7: "URL normalization").
export function canonicalizeUrl(rawUrl: string): string {
  try {
    const u = new URL(rawUrl);
    const trackingParams = [
      "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
      "ref", "fbclid", "gclid", "mc_cid", "mc_eid", "igshid", "_hsenc", "_hsmi",
    ];
    for (const p of trackingParams) u.searchParams.delete(p);
    u.hash = "";
    u.hostname = u.hostname.toLowerCase();
    const path = u.pathname.replace(/\/+$/, "");
    return `${u.protocol}//${u.hostname}${path}${u.search}`;
  } catch {
    return rawUrl.trim().toLowerCase();
  }
}

const COMBINING_MARKS = /[̀-ͯ]/g;

/// Lowercases, strips accents/punctuation, and collapses whitespace so
/// trivially different titles ("Foo Launches v2!" vs "foo launches v2")
/// still hash the same (spec section 7: "title similarity", implemented as
/// normalized exact-match rather than fuzzy distance — cheap and reliable
/// for the common case of the same headline echoed by multiple outlets).
export function normalizeTitle(title: string): string {
  return title
    .toLowerCase()
    .normalize("NFKD")
    .replace(COMBINING_MARKS, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/// Dedup key combining the normalized title with the canonical URL's host —
/// two different stories on the same host never collide, but the same
/// story mirrored across sources with slightly different URLs still does.
export async function contentHash(title: string, url: string): Promise<string> {
  const host = safeHost(url);
  const input = `${normalizeTitle(title)}|${host}`;
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function safeHost(url: string): string {
  try {
    return new URL(url).hostname.toLowerCase().replace(/^www\./, "");
  } catch {
    return "";
  }
}

/// Clamps a score into [0, 100].
export function clampScore(n: number): number {
  return Math.max(0, Math.min(100, Math.round(n * 100) / 100));
}
