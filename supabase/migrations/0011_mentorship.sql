-- 0011_mentorship.sql

create table mentor_profiles (
  profile_id uuid primary key references profiles(id) on delete cascade,
  available boolean not null default true,
  expertise text[] not null default '{}',
  topics text[] not null default '{}',
  session_duration_minutes integer not null default 30 check (session_duration_minutes > 0),
  pricing_type pricing_type not null default 'free',
  price numeric(10,2) check (price is null or price >= 0),
  currency text default 'USD',
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table mentor_requests (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references profiles(id) on delete cascade,
  requester_id uuid not null references profiles(id) on delete cascade,
  topic text,
  message text,
  status mentor_request_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mentor_requests_no_self check (mentor_id <> requester_id)
);

create index mentor_requests_mentor_idx on mentor_requests(mentor_id);
create index mentor_requests_requester_idx on mentor_requests(requester_id);

create table mentor_sessions (
  id uuid primary key default gen_random_uuid(),
  mentor_request_id uuid not null references mentor_requests(id) on delete cascade,
  scheduled_at timestamptz not null,
  duration_minutes integer not null default 30,
  status mentor_session_status not null default 'scheduled',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
