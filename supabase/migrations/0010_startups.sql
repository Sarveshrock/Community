-- 0010_startups.sql

create table startups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  logo_url text,
  description text,
  industry text,
  stage startup_stage not null default 'idea',
  location text,
  website text,
  team_size integer check (team_size is null or team_size >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index startups_owner_idx on startups(owner_id);

create table startup_members (
  startup_id uuid not null references startups(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  role text,
  is_founder boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (startup_id, profile_id)
);

create table startup_opportunities (
  id uuid primary key default gen_random_uuid(),
  startup_id uuid not null references startups(id) on delete cascade,
  title text not null,
  description text,
  role text,
  compensation_type compensation_type not null default 'negotiable',
  is_remote boolean not null default true,
  status opportunity_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index startup_opportunities_startup_idx on startup_opportunities(startup_id);
create index startup_opportunities_status_idx on startup_opportunities(status);
