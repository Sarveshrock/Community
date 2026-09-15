// GitHub trending — deliberately NOT "sort by total stars." GitHub has no
// official "trending" API/score; this computes one ourselves from two
// signals:
//  1. Newly-created repos that are already popular (a reasonable proxy the
//     first time we ever see a repo, when we have no history for it yet).
//  2. Real week-over-week star velocity, once we've seen a repo more than
//     once — using our own snapshot history in github_repo_snapshots,
//     never claiming this came from GitHub itself.
//
// Matches the spec's own example: a 100k-star repo that gained 50 stars
// this week should rank below an 8k-star repo that gained 2,000.

import { RawNewsItem } from "../utils/types.ts";

interface GithubRepo {
  full_name: string;
  html_url: string;
  description: string | null;
  stargazers_count: number;
  forks_count: number;
  created_at: string;
  pushed_at: string;
  language: string | null;
  owner: { login: string };
}

async function searchRepos(query: string, sort: string, perPage: number, token?: string): Promise<GithubRepo[]> {
  const url = `https://api.github.com/search/repositories?q=${encodeURIComponent(query)}&sort=${sort}&order=desc&per_page=${perPage}`;
  const headers: Record<string, string> = { Accept: "application/vnd.github+json", "User-Agent": "community-app-tech-intel" };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`GitHub API error: ${res.status}`);
  const json = await res.json();
  return (json.items ?? []) as GithubRepo[];
}

/// db is a minimal shape (only the methods used here) so this file doesn't
/// need to import the full Supabase client type.
interface SnapshotDb {
  from(table: string): any;
}

async function scoreRepo(
  db: SnapshotDb,
  repo: GithubRepo,
): Promise<{ score: number; confidence: "measured" | "estimated"; velocityPerDay: number | null }> {
  const { data: history } = await db
    .from("github_repo_snapshots")
    .select("stars, snapshot_at")
    .eq("repo_full_name", repo.full_name)
    .order("snapshot_at", { ascending: true })
    .limit(1);

  const baseline = (history ?? [])[0] as { stars: number; snapshot_at: string } | undefined;

  if (baseline) {
    const daysBetween = Math.max(1, (Date.now() - new Date(baseline.snapshot_at).getTime()) / 86_400_000);
    const velocityPerDay = (repo.stargazers_count - baseline.stars) / daysBetween;
    // 100 stars/day is treated as an extremely hot repo (score 100).
    const score = Math.max(0, Math.min(100, (velocityPerDay / 100) * 100));
    return { score, confidence: "measured", velocityPerDay };
  }

  // No history yet: fall back to a "new + already popular" proxy.
  const ageDays = Math.max(0, (Date.now() - new Date(repo.created_at).getTime()) / 86_400_000);
  const recencyScore = Math.max(0, 100 - ageDays * 10);
  const starScale = Math.min(Math.log10(repo.stargazers_count + 1) / 5, 1) * 100;
  const score = recencyScore * 0.5 + starScale * 0.5;
  return { score, confidence: "estimated", velocityPerDay: null };
}

/// Throttles snapshot writes to roughly once per 20h per repo so this table
/// doesn't grow unbounded on a 30-minute schedule (spec section 16: avoid
/// unnecessary duplicate work).
async function maybeRecordSnapshot(db: SnapshotDb, repo: GithubRepo): Promise<void> {
  const { data: recent } = await db
    .from("github_repo_snapshots")
    .select("id")
    .eq("repo_full_name", repo.full_name)
    .gte("snapshot_at", new Date(Date.now() - 20 * 3_600_000).toISOString())
    .limit(1);
  if (recent && recent.length > 0) return;

  await db.from("github_repo_snapshots").insert({
    repo_full_name: repo.full_name,
    stars: repo.stargazers_count,
    forks: repo.forks_count,
  });
}

export async function fetchGithubTrending(db: SnapshotDb, limit: number): Promise<RawNewsItem[]> {
  const token = Deno.env.get("GITHUB_TOKEN");
  const perQuery = Math.ceil(limit / 2);

  const sevenDaysAgo = new Date(Date.now() - 7 * 86_400_000).toISOString().slice(0, 10);
  const threeDaysAgo = new Date(Date.now() - 3 * 86_400_000).toISOString().slice(0, 10);

  const [freshlyPopular, activelyMaintained] = await Promise.all([
    searchRepos(`created:>${sevenDaysAgo}`, "stars", perQuery, token),
    searchRepos(`pushed:>${threeDaysAgo} stars:>500`, "updated", perQuery, token),
  ]);

  const byName = new Map<string, GithubRepo>();
  for (const r of [...freshlyPopular, ...activelyMaintained]) byName.set(r.full_name, r);

  const items: RawNewsItem[] = [];
  for (const repo of byName.values()) {
    const { score, confidence, velocityPerDay } = await scoreRepo(db, repo);
    await maybeRecordSnapshot(db, repo);

    items.push({
      title: repo.full_name,
      description: repo.description ?? undefined,
      url: repo.html_url,
      source: "GitHub",
      source_type: "github",
      published_at: repo.pushed_at,
      author: repo.owner?.login,
      tags: repo.language ? [repo.language] : [],
      metadata: {
        stars: repo.stargazers_count,
        forks: repo.forks_count,
        language: repo.language,
        github_trending_score: Math.round(score * 100) / 100,
        trending_confidence: confidence,
        velocity_per_day: velocityPerDay,
      },
    });
  }
  return items;
}
