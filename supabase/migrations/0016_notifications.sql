-- 0016_notifications.sql

create table notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_profile_created_idx on notifications(profile_id, created_at desc);

create table device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  token text not null,
  platform text not null default 'unknown',
  created_at timestamptz not null default now(),
  constraint device_tokens_unique unique (profile_id, token)
);

create table notification_preferences (
  profile_id uuid primary key references profiles(id) on delete cascade,
  messages boolean not null default true,
  connections boolean not null default true,
  jobs boolean not null default true,
  hackathons boolean not null default true,
  projects boolean not null default true,
  mentorship boolean not null default true,
  local_requests boolean not null default true,
  meetups boolean not null default true,
  news boolean not null default true,
  community_events boolean not null default true,
  updated_at timestamptz not null default now()
);
