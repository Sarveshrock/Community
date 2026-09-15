-- 0038_intent_matches.sql
-- Cached, explainable match results for an intent (spec-extension: Matching
-- Engine). Deliberately a dedicated table rather than reusing
-- ai_recommendations (0017_ai.sql) — intent matches need structured
-- matched/missing/complementary-skill and availability fields that don't
-- fit that generic shape. Rows are written only by the ai-match-intent edge
-- function's service-role client (see supabase/functions/ai-match-intent) —
-- there is intentionally no insert/update/delete RLS policy, the same trust
-- model already used for ai_recommendations (never written directly by a
-- client).

create table intent_matches (
  id uuid primary key default gen_random_uuid(),
  intent_id uuid not null references intents(id) on delete cascade,
  candidate_id uuid not null references profiles(id) on delete cascade,
  score numeric(5,2) not null check (score >= 0 and score <= 100),
  matched_skills text[] not null default '{}',
  missing_skills text[] not null default '{}',
  complementary_skills text[] not null default '{}',
  shared_interests text[] not null default '{}',
  availability_compatible boolean,
  reasons text[] not null default '{}',
  model_version text,
  created_at timestamptz not null default now(),
  constraint intent_matches_unique unique (intent_id, candidate_id)
);

create index intent_matches_intent_score_idx on intent_matches(intent_id, score desc);

alter table intent_matches enable row level security;

create policy intent_matches_select on intent_matches for select
  using (auth.uid() = (select profile_id from intents where id = intent_id));
