-- 0007_hackathons.sql

create table hackathons (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  description text,
  organizer text,
  start_at timestamptz not null,
  end_at timestamptz not null,
  registration_deadline timestamptz,
  mode hackathon_mode not null default 'online',
  location text,
  team_min_size integer not null default 1 check (team_min_size >= 1),
  team_max_size integer not null default 4 check (team_max_size >= team_min_size),
  prize_description text,
  theme text,
  rules text,
  registration_url text,
  team_formation_enabled boolean not null default true,
  status text not null default 'upcoming',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hackathons_date_range check (end_at >= start_at)
);

create index hackathons_start_at_idx on hackathons(start_at);
create index hackathons_registration_deadline_idx on hackathons(registration_deadline);

create table hackathon_participants (
  id uuid primary key default gen_random_uuid(),
  hackathon_id uuid not null references hackathons(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  status participant_status not null default 'registered',
  created_at timestamptz not null default now(),
  constraint hackathon_participants_unique unique (hackathon_id, profile_id)
);

create table hackathon_team_requirements (
  id uuid primary key default gen_random_uuid(),
  hackathon_id uuid not null references hackathons(id) on delete cascade,
  creator_id uuid not null references profiles(id) on delete cascade,
  team_name text not null,
  description text,
  required_roles text[] not null default '{}',
  team_size integer not null default 4 check (team_size >= 1),
  status team_requirement_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table hackathon_team_required_skills (
  team_requirement_id uuid not null references hackathon_team_requirements(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete cascade,
  primary key (team_requirement_id, skill_id)
);

create table team_invitations (
  id uuid primary key default gen_random_uuid(),
  team_requirement_id uuid not null references hackathon_team_requirements(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  receiver_id uuid not null references profiles(id) on delete cascade,
  status invitation_status not null default 'pending',
  message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint team_invitations_no_self check (sender_id <> receiver_id)
);

create index team_invitations_receiver_idx on team_invitations(receiver_id);
create index hackathon_team_requirements_hackathon_idx on hackathon_team_requirements(hackathon_id);
