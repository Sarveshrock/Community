-- 0025_tech_intelligence_pipeline.sql
-- Automated multi-source tech intelligence pipeline (Hacker News, GitHub,
-- arXiv, Semantic Scholar, Hugging Face, tech RSS feeds, Show HN, optional
-- X/Twitter). Nothing is ever inserted manually — the get-news Edge
-- Function runs the full fetch -> normalize -> deduplicate -> filter ->
-- categorize -> score -> store pipeline itself, on a schedule (see the
-- pg_cron job at the bottom) or on demand.

create table news_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  url text not null,
  source text not null,
  source_type text not null,
  author text,
  image_url text,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  category text not null default 'Other Tech',
  tags text[] not null default '{}',
  tech_relevance_score numeric(5,2) not null default 0,
  importance_score numeric(5,2) not null default 0,
  trending_score numeric(5,2) not null default 0,
  final_score numeric(5,2) not null default 0,
  is_trending boolean not null default false,
  is_featured boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  content_hash text not null
);

comment on column news_items.content_hash is
  'Dedup key: sha256 of the canonicalized URL + normalized title, so the same story from multiple sources collapses to one row (see filters/deduplication.ts).';
comment on column news_items.final_score is
  'Weighted combination of freshness/tech_relevance/importance/trending/source_quality (see news_ranking_config) — what the feed orders by.';

create unique index news_items_content_hash_idx on news_items(content_hash);
create index news_items_published_at_idx on news_items(published_at desc);
create index news_items_category_idx on news_items(category);
create index news_items_source_idx on news_items(source);
create index news_items_source_type_idx on news_items(source_type);
create index news_items_is_trending_idx on news_items(is_trending) where is_trending;
create index news_items_final_score_idx on news_items(final_score desc);

alter table news_items enable row level security;
create policy news_items_select_all on news_items for select using (true);
-- No client insert/update/delete policy at all: only the get-news Edge
-- Function (service role, bypasses RLS) ever writes here.

-- Our own star-count history per repo so GitHub trending can become a real
-- week-over-week velocity once a repo has been seen more than once, rather
-- than only a "new + already popular" proxy for first-sight repos. Never
-- claims to be an official GitHub trending score — GitHub doesn't expose
-- one; this is entirely our own calculated metric (see sources/github.ts).
create table github_repo_snapshots (
  id uuid primary key default gen_random_uuid(),
  repo_full_name text not null,
  stars integer not null,
  forks integer not null,
  snapshot_at timestamptz not null default now()
);

create index github_repo_snapshots_repo_idx on github_repo_snapshots(repo_full_name, snapshot_at desc);
alter table github_repo_snapshots enable row level security;
-- Service-role only — intentionally no client policies.

-- Configurable ranking weights + relevance/trending thresholds (spec: "must
-- not be hardcoded throughout the codebase"), mirroring the existing
-- ai_scoring_weights precedent (0017_ai.sql) — editable via SQL without a
-- redeploy.
create table news_ranking_config (
  id text primary key default 'default',
  relevance_threshold numeric(5,2) not null default 45,
  trending_threshold numeric(5,2) not null default 70,
  weight_freshness numeric(4,3) not null default 0.25,
  weight_tech_relevance numeric(4,3) not null default 0.30,
  weight_importance numeric(4,3) not null default 0.20,
  weight_trending numeric(4,3) not null default 0.15,
  weight_source_quality numeric(4,3) not null default 0.10,
  updated_at timestamptz not null default now()
);

insert into news_ranking_config (id) values ('default');

alter table news_ranking_config enable row level security;
-- Service-role only — the function reads it, nobody else needs to.

create trigger set_updated_at before update on news_items
  for each row execute function handle_updated_at();

-- ============================================================================
-- Automatic periodic execution (spec section 17)
-- ============================================================================
-- pg_cron + pg_net call the get-news Edge Function on a schedule. The job
-- reads its auth header from Vault by name rather than embedding the actual
-- secret, so nothing sensitive is ever committed in this file — the secret
-- itself is set once, directly against the project, via:
--   select vault.create_secret('<your SERVICE_FUNCTION_SECRET value>', 'service_function_secret');
-- (never as part of a migration, so it's never in git history).
--
-- Replace your-project-ref and your-anon-public-key below with your
-- actual project's values before running, or update the job afterwards by
-- re-running this same cron.schedule() call (same job name = update, not a
-- duplicate). Neither value is secret — both are the same public
-- SUPABASE_URL/SUPABASE_ANON_KEY already shipped in the Flutter app's own
-- .env — they're placeholders here only so this file stays portable across
-- projects. The Authorization header is required by Supabase's own Edge
-- Function gateway (which checks it before your code ever runs); the
-- x-service-secret header is this app's own authorization check on top of
-- that.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'refresh-tech-news',
  '*/30 * * * *',
  $$
  select net.http_post(
    url := 'https://your-project-ref.supabase.co/functions/v1/get-news',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer your-anon-public-key',
      'x-service-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'service_function_secret')
    ),
    body := jsonb_build_object('mode', 'refresh')
  );
  $$
);
