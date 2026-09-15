-- 0017_ai.sql

create table ai_recommendations (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  candidate_id uuid not null,
  recommendation_type recommendation_type not null,
  score numeric(5,2) not null check (score >= 0 and score <= 100),
  reason text,
  model_version text,
  created_at timestamptz not null default now()
);

create index ai_recommendations_profile_idx on ai_recommendations(profile_id, recommendation_type, score desc);

create table ai_match_scores (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  candidate_id uuid not null,
  recommendation_type recommendation_type not null,
  skills_score numeric(5,2) default 0,
  interests_score numeric(5,2) default 0,
  goals_score numeric(5,2) default 0,
  experience_score numeric(5,2) default 0,
  availability_score numeric(5,2) default 0,
  location_score numeric(5,2) default 0,
  activity_score numeric(5,2) default 0,
  total_score numeric(5,2) not null default 0,
  created_at timestamptz not null default now()
);

create table ai_feedback (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  recommendation_id uuid references ai_recommendations(id) on delete cascade,
  feedback text not null,
  created_at timestamptz not null default now()
);

-- Configurable scoring weights (see spec section 43). Editable by admins only.
create table ai_scoring_weights (
  recommendation_type recommendation_type primary key,
  skills_weight numeric(4,2) not null default 0.35,
  interests_weight numeric(4,2) not null default 0.20,
  goals_weight numeric(4,2) not null default 0.15,
  experience_weight numeric(4,2) not null default 0.10,
  availability_weight numeric(4,2) not null default 0.10,
  location_weight numeric(4,2) not null default 0.05,
  activity_weight numeric(4,2) not null default 0.05,
  updated_at timestamptz not null default now()
);

-- Optional embeddings for semantic candidate retrieval. Columns are nullable
-- and only populated where pgvector is available and genuinely useful.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'vector') then
    alter table profiles add column if not exists profile_embedding vector(1536);
    alter table projects add column if not exists project_embedding vector(1536);
    alter table jobs add column if not exists job_embedding vector(1536);
    alter table hackathons add column if not exists hackathon_embedding vector(1536);
    alter table startup_opportunities add column if not exists opportunity_embedding vector(1536);
    alter table news_items add column if not exists news_embedding vector(1536);
  end if;
end $$;
