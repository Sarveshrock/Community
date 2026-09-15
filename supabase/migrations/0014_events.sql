-- 0014_events.sql

create table events (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references profiles(id) on delete cascade,
  community_id uuid references communities(id) on delete set null,
  title text not null,
  description text,
  event_type event_type not null default 'community_event',
  mode hackathon_mode not null default 'online',
  location text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  registration_url text,
  cover_image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint events_date_range check (ends_at is null or ends_at >= starts_at)
);

create index events_starts_at_idx on events(starts_at);

create table event_attendees (
  event_id uuid not null references events(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  registered_at timestamptz not null default now(),
  primary key (event_id, profile_id)
);
