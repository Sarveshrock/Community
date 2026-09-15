-- 0008_projects.sql

create table projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  description text,
  category text,
  collaboration_type collaboration_type not null default 'personal',
  compensation_type compensation_type not null default 'unpaid',
  compensation_details text,
  time_commitment_hours integer check (time_commitment_hours is null or time_commitment_hours >= 0),
  duration_description text,
  status project_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index projects_status_idx on projects(status);
create index projects_owner_idx on projects(owner_id);

create table project_requirements (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  role text not null,
  description text,
  required_experience text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table project_required_skills (
  project_id uuid not null references projects(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete cascade,
  primary key (project_id, skill_id)
);

create table project_interests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  message text,
  status project_interest_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint project_interests_unique unique (project_id, profile_id)
);

create index project_interests_project_idx on project_interests(project_id);
create index project_interests_profile_idx on project_interests(profile_id);
