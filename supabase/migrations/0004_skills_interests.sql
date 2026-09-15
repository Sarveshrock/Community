-- 0004_skills_interests.sql

create table skills (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  normalized_name text not null unique,
  category text,
  created_at timestamptz not null default now()
);

create table profile_skills (
  profile_id uuid not null references profiles(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete cascade,
  experience_level experience_level not null default 'intermediate',
  years_experience numeric(4,1) check (years_experience is null or years_experience >= 0),
  created_at timestamptz not null default now(),
  primary key (profile_id, skill_id)
);

create table interests (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  normalized_name text not null unique,
  created_at timestamptz not null default now()
);

create table profile_interests (
  profile_id uuid not null references profiles(id) on delete cascade,
  interest_id uuid not null references interests(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, interest_id)
);

create table optional_proofs (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  proof_type proof_type not null,
  url text,
  title text,
  description text,
  verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table optional_proofs is 'Entirely optional proof-of-skill links. Never required for profile completion.';
