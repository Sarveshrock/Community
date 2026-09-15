// get-news — automated tech intelligence pipeline (multi-source fetch ->
// normalize -> deduplicate -> filter -> categorize -> rank -> store).
// Nothing is ever inserted manually: this function IS the only writer to
// news_items, invoked either by the pg_cron schedule (see migration
// 0025_tech_intelligence_pipeline.sql) or on demand by a signed-in user
// (useful for manually refreshing while testing). Flutter reads the
// resulting feed straight from news_items via PostgREST (paginated,
// server-filtered) — this function is not on that read path.

import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { requireUserId, serviceClient } from "../_shared/supabaseClient.ts";
import { getAiProvider } from "../_shared/aiProvider.ts";
import { RawNewsItem } from "./utils/types.ts";
import { logStep, logSourceResult, logWarn } from "./utils/logging.ts";
import { fetchHackerNews } from "./sources/hackernews.ts";
import { fetchStartupLaunches } from "./sources/startups.ts";
import { fetchArxiv } from "./sources/arxiv.ts";
import { fetchSemanticScholar } from "./sources/semanticscholar.ts";
import { fetchHuggingFaceTrending } from "./sources/huggingface.ts";
import { fetchTechNews } from "./sources/technews.ts";
import { fetchGithubTrending } from "./sources/github.ts";
import { fetchXPosts, isXConfigured } from "./sources/x.ts";
import { deduplicate } from "./filters/deduplication.ts";
import { scoreRelevance } from "./filters/relevance.ts";
import { refineBorderlineRelevance } from "./filters/aiRelevance.ts";
import { rankItem, RankingWeights } from "./filters/ranking.ts";

const FETCH_WINDOW_HOURS = 48;
const FEATURED_COUNT = 5;

async function requireCallerOrService(req: Request): Promise<string> {
  const serviceSecret = req.headers.get("x-service-secret");
  if (serviceSecret && serviceSecret === Deno.env.get("SERVICE_FUNCTION_SECRET")) {
    return "cron";
  }
  return requireUserId(req);
}

/// Runs every source independently — one broken/slow source must never
/// take the others down with it (spec section 21).
async function fetchAllSources(db: ReturnType<typeof serviceClient>): Promise<RawNewsItem[]> {
  const jobs: { name: string; run: () => Promise<RawNewsItem[]> }[] = [
    { name: "Hacker News", run: () => fetchHackerNews(FETCH_WINDOW_HOURS, 40) },
    { name: "Show HN", run: () => fetchStartupLaunches(FETCH_WINDOW_HOURS, 20) },
    { name: "arXiv", run: () => fetchArxiv(40) },
    { name: "Semantic Scholar", run: () => fetchSemanticScholar(20) },
    { name: "Hugging Face", run: () => fetchHuggingFaceTrending(20) },
    { name: "Tech RSS", run: () => fetchTechNews(15) },
    { name: "GitHub", run: () => fetchGithubTrending(db, 40) },
  ];
  if (isXConfigured()) {
    jobs.push({ name: "X", run: () => fetchXPosts(20) });
  } else {
    logStep("X", "skipped — X_BEARER_TOKEN not configured (optional source)");
  }

  const results = await Promise.allSettled(jobs.map((j) => j.run()));
  const items: RawNewsItem[] = [];
  results.forEach((r, i) => {
    if (r.status === "fulfilled") {
      logSourceResult(jobs[i].name, r.value.length);
      items.push(...r.value);
    } else {
      logSourceResult(jobs[i].name, 0, r.reason);
    }
  });
  return items;
}

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  const startedAt = Date.now();

  try {
    await requireCallerOrService(req);
    const db = serviceClient();

    const { data: configRow } = await db.from("news_ranking_config").select("*").eq("id", "default").single();
    const config = configRow ?? {
      relevance_threshold: 45,
      trending_threshold: 70,
      weight_freshness: 0.25,
      weight_tech_relevance: 0.3,
      weight_importance: 0.2,
      weight_trending: 0.15,
      weight_source_quality: 0.1,
    };
    const weights: RankingWeights = {
      weight_freshness: Number(config.weight_freshness),
      weight_tech_relevance: Number(config.weight_tech_relevance),
      weight_importance: Number(config.weight_importance),
      weight_trending: Number(config.weight_trending),
      weight_source_quality: Number(config.weight_source_quality),
    };
    const relevanceThreshold = Number(config.relevance_threshold);
    const trendingThreshold = Number(config.trending_threshold);

    const raw = await fetchAllSources(db);
    logStep("Pipeline", `${raw.length} raw items across all sources`);

    const deduped = await deduplicate(raw);
    logStep("Deduplication", `${raw.length} -> ${deduped.length} unique`);

    let scored = deduped.map((item) => ({ item, ...scoreRelevance(item) }));
    const ai = getAiProvider();
    const refined = await refineBorderlineRelevance(
      ai,
      relevanceThreshold,
      scored.map((s) => ({ item: s.item, score: s.score })),
    );
    scored = scored.map((s, i) => ({ ...s, score: refined[i].score }));

    const relevant = scored.filter((s) => s.score >= relevanceThreshold);
    logStep("Filter", `${scored.length} -> ${relevant.length} relevant (threshold ${relevanceThreshold})`);

    const ranked = relevant
      .map((s) => rankItem(s.item, { score: s.score, category: s.category, tags: s.tags }, weights))
      .sort((a, b) => b.final_score - a.final_score);
    logStep("Ranking", "completed");

    const featuredHashes = new Set(ranked.slice(0, FEATURED_COUNT).map((r) => r.content_hash));
    const rows = ranked.map((r) => ({
      title: r.title,
      description: r.description ?? null,
      url: r.url,
      source: r.source,
      source_type: r.source_type,
      author: r.author ?? null,
      image_url: r.image_url ?? null,
      published_at: r.published_at ?? null,
      category: r.category,
      tags: r.tags,
      tech_relevance_score: r.tech_relevance_score,
      importance_score: r.importance_score,
      trending_score: r.trending_score,
      final_score: r.final_score,
      is_trending: r.trending_score >= trendingThreshold,
      is_featured: featuredHashes.has(r.content_hash),
      metadata: r.metadata ?? {},
      content_hash: r.content_hash,
    }));

    let inserted = 0;
    let updated = 0;
    if (rows.length > 0) {
      const hashes = rows.map((r) => r.content_hash);
      const { data: existing } = await db.from("news_items").select("content_hash").in("content_hash", hashes);
      const existingHashes = new Set((existing ?? []).map((e: { content_hash: string }) => e.content_hash));
      inserted = rows.filter((r) => !existingHashes.has(r.content_hash)).length;
      updated = rows.length - inserted;

      const { error: upsertError } = await db.from("news_items").upsert(rows, { onConflict: "content_hash" });
      if (upsertError) throw upsertError;

      // Keep "featured" meaning "currently hot," not a permanent badge —
      // clear it from anything outside this run's top slice.
      if (featuredHashes.size > 0) {
        await db
          .from("news_items")
          .update({ is_featured: false })
          .eq("is_featured", true)
          .not("content_hash", "in", `(${Array.from(featuredHashes).join(",")})`);
      }
    }
    logStep("Database", `upserted ${rows.length} rows (${inserted} new, ${updated} updated)`);

    return jsonResponse({
      sources_fetched: raw.length,
      unique_after_dedup: deduped.length,
      relevant_after_filter: relevant.length,
      stored: rows.length,
      inserted,
      updated,
      duration_ms: Date.now() - startedAt,
    });
  } catch (err) {
    logWarn("Pipeline", `failed: ${(err as Error).message}`);
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
