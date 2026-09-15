-- 0012_local.sql
-- Local 1-to-1 discovery. Strictly separate from professional connections.

create table local_profiles (
  profile_id uuid primary key references profiles(id) on delete cascade,
  enabled boolean not null default false,
  approximate_city text,
  approximate_area text,
  preferred_radius_km integer not null default 5 check (preferred_radius_km > 0),
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index local_profiles_approx_city_idx on local_profiles(approximate_city);

create table local_preferences (
  profile_id uuid primary key references profiles(id) on delete cascade,
  activity_preferences text[] not null default '{}',
  interest_preferences text[] not null default '{}',
  availability_preferences text[] not null default '{}',
  age_range_preference int4range,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table local_connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(id) on delete cascade,
  receiver_id uuid not null references profiles(id) on delete cascade,
  status connection_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint local_connections_no_self check (requester_id <> receiver_id)
);

create unique index local_connections_unique_pair_active
  on local_connections (least(requester_id, receiver_id), greatest(requester_id, receiver_id))
  where status in ('pending', 'accepted');

create index local_connections_requester_idx on local_connections(requester_id);
create index local_connections_receiver_idx on local_connections(receiver_id);

create table meetup_suggestions (
  id uuid primary key default gen_random_uuid(),
  local_connection_id uuid not null references local_connections(id) on delete cascade,
  suggested_by uuid not null references profiles(id) on delete cascade,
  activity_type text not null,
  suggested_area text,
  suggested_place_name text,
  suggested_at timestamptz,
  message text,
  status meetup_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index meetup_suggestions_connection_idx on meetup_suggestions(local_connection_id);

-- Enforce: a meetup suggestion may only be created once the underlying local
-- connection is accepted, and the suggester must be part of that connection.
create or replace function enforce_meetup_requires_accepted_connection()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  conn local_connections%rowtype;
begin
  select * into conn from local_connections where id = new.local_connection_id;
  if conn.id is null then
    raise exception 'local connection not found';
  end if;
  if conn.status <> 'accepted' then
    raise exception 'local connection must be accepted before suggesting a meetup';
  end if;
  if new.suggested_by not in (conn.requester_id, conn.receiver_id) then
    raise exception 'suggested_by must be a participant in the local connection';
  end if;
  return new;
end;
$$;

create trigger meetup_suggestions_require_accepted
  before insert on meetup_suggestions
  for each row execute function enforce_meetup_requires_accepted_connection();
