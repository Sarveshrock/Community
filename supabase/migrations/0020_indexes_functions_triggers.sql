-- 0020_indexes_functions_triggers.sql
-- Remaining indexes, updated_at triggers, auth trigger, privacy-safe local search.

-- ============================================================================
-- Additional indexes (spec section 82)
-- ============================================================================

create index if not exists profiles_city_idx on profiles(city);
create index if not exists profiles_primary_user_type_idx on profiles(primary_user_type);
create index if not exists profiles_professional_discoverable_idx on profiles(professional_discoverable);
create index if not exists profiles_local_discoverable_idx on profiles(local_discoverable);
create index if not exists local_profiles_approx_city_idx2 on local_profiles(approximate_city);
create index if not exists notifications_profile_created_idx2 on notifications(profile_id, created_at);

-- ============================================================================
-- updated_at trigger helper
-- ============================================================================

create or replace function handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
  mutable_tables text[] := array[
    'profiles', 'experiences', 'education', 'optional_proofs',
    'connections', 'conversations', 'messages',
    'hackathons', 'hackathon_team_requirements', 'team_invitations',
    'projects', 'project_requirements', 'project_interests',
    'jobs', 'job_applications',
    'startups', 'startup_opportunities',
    'mentor_profiles', 'mentor_requests', 'mentor_sessions',
    'local_profiles', 'local_preferences', 'local_connections', 'meetup_suggestions',
    'communities', 'community_posts', 'community_comments',
    'events', 'news_items', 'notification_preferences'
  ];
begin
  foreach t in array mutable_tables loop
    execute format(
      'drop trigger if exists set_updated_at on %I; create trigger set_updated_at before update on %I for each row execute function handle_updated_at();',
      t, t
    );
  end loop;
end $$;

-- ============================================================================
-- Auth -> profile bootstrap trigger
-- ============================================================================

create or replace function handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  insert into public.notification_preferences (profile_id) values (new.id)
  on conflict (profile_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_auth_user();

-- ============================================================================
-- Privacy-safe local discovery (spec section 51)
-- Returns only distance buckets and public fields, never coordinates.
-- ============================================================================

create or replace function distance_bucket_km(km numeric)
returns text
language sql
immutable
as $$
  select case
    when km is null then 'nearby'
    when km < 1 then '<1 km'
    when km < 3 then '1-3 km'
    when km < 5 then '3-5 km'
    when km < 10 then '5-10 km'
    else '10+ km'
  end;
$$;

-- Great-circle distance in km via the haversine formula (no extra extensions required).
create or replace function haversine_km(lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric)
returns numeric
language sql
immutable
as $$
  select 6371 * acos(
    least(1::double precision, greatest(-1::double precision,
      sin(radians(lat1::double precision)) * sin(radians(lat2::double precision))
      + cos(radians(lat1::double precision)) * cos(radians(lat2::double precision))
        * cos(radians(lng2::double precision) - radians(lng1::double precision))
    ))
  )::numeric;
$$;

create or replace function get_local_candidates(result_limit integer default 20)
returns table (
  profile_id uuid,
  display_name text,
  avatar_url text,
  approximate_distance_bucket text,
  city text,
  area text,
  bio text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  caller uuid := auth.uid();
  caller_lat numeric;
  caller_lng numeric;
begin
  if caller is null then
    raise exception 'not authenticated';
  end if;

  select p.approx_latitude, p.approx_longitude into caller_lat, caller_lng
  from profiles p
  join local_profiles lp on lp.profile_id = p.id
  where p.id = caller and lp.enabled = true;

  if caller_lat is null then
    raise exception 'local discovery not enabled for this profile';
  end if;

  return query
  select
    p.id,
    p.full_name,
    p.avatar_url,
    distance_bucket_km(
      case when p.approx_latitude is not null and p.approx_longitude is not null then
        haversine_km(caller_lat, caller_lng, p.approx_latitude, p.approx_longitude)
      else null end
    ),
    lp.approximate_city,
    lp.approximate_area,
    lp.bio
  from profiles p
  join local_profiles lp on lp.profile_id = p.id
  where p.id <> caller
    and lp.enabled = true
    and p.local_discoverable = true
    and not is_blocked(caller, p.id)
    and not exists (
      select 1 from local_connections lc
      where lc.status in ('pending', 'accepted')
        and ((lc.requester_id = caller and lc.receiver_id = p.id)
          or (lc.requester_id = p.id and lc.receiver_id = caller))
    )
  order by p.approx_latitude is null, random()
  limit result_limit;
end;
$$;

comment on function get_local_candidates is
  'Privacy-safe local discovery: exposes only distance buckets, never exact coordinates.';
