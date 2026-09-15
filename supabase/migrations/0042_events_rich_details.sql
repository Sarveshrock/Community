-- 0042_events_rich_details.sql
-- Events redesign (Phase 1): the event creation form and detail page only
-- ever collected title/description/type/mode/location/start time. This
-- migration adds the richer, genuinely useful fields the new Event Builder
-- and Event Detail page need — category breadth, date/time detail,
-- conditional location fields, audience/registration, informational
-- pricing (no payment processing exists anywhere in this app, so this is
-- display-only, ready for real payment integration later), requirements/
-- benefits, a real agenda, real speakers (linked to existing profiles
-- where possible, never duplicate people records), and an invite-only
-- join-request workflow mirroring the existing hackathon team join-request
-- pattern (0026_team_join_requests_and_notifications.sql) exactly.
--
-- Explicitly deferred (per product decision): hackathon-specific fields
-- (team size, prize pool, tracks, judging) stay in the existing, separate
-- Hackathons feature rather than being duplicated onto generic events;
-- real payment/ticketing processing; recurring events; organizer
-- analytics; manage-participants/send-announcement screens.

-- ============================================================================
-- Enums
-- ============================================================================

-- Additive only — existing rows/values are untouched.
alter type event_type add value if not exists 'meetup';
alter type event_type add value if not exists 'webinar';
alter type event_type add value if not exists 'networking';
alter type event_type add value if not exists 'competition';
alter type event_type add value if not exists 'other';

create type event_visibility as enum ('public', 'connections', 'invite_only');
create type event_status as enum ('published', 'cancelled');

-- ============================================================================
-- events: new columns (all nullable or defaulted, so existing rows/inserts
-- from before this migration keep working unchanged)
-- ============================================================================

alter table events
  add column short_description text,
  add column is_all_day boolean not null default false,
  add column timezone text not null default 'UTC',
  add column meeting_platform text,
  add column venue_name text,
  add column city text,
  add column state text,
  add column max_participants integer check (max_participants is null or max_participants > 0),
  add column registration_required boolean not null default true,
  add column registration_deadline timestamptz,
  add column visibility event_visibility not null default 'public',
  add column audience text[] not null default '{}',
  add column is_free boolean not null default true,
  add column price numeric(10, 2) check (price is null or price >= 0),
  add column currency text not null default 'INR',
  add column what_to_bring text[] not null default '{}',
  add column prerequisites text,
  add column benefits text[] not null default '{}',
  add column skill_level text,
  add column required_software text[] not null default '{}',
  add column status event_status not null default 'published',
  add column cancelled_at timestamptz,
  add column cancellation_reason text;

create index events_status_idx on events(status);
create index events_visibility_idx on events(visibility);

-- ============================================================================
-- event_private_details — the meeting link/joining instructions and exact
-- address, split into their own row with restrictive RLS rather than kept
-- as columns on `events` (which stays fully selectable by design, since
-- title/date/etc. must be publicly listable). Column-level masking inside
-- a function can't actually protect a field while the underlying table's
-- own SELECT policy still allows reading it directly via the same REST
-- API — so real protection has to be a separate, real RLS-gated table.
-- Same pattern this app already relies on elsewhere (a pet name's embed
-- comes back empty when RLS hides the other party's row) rather than a
-- new one.
-- ============================================================================

create table event_private_details (
  event_id uuid primary key references events(id) on delete cascade,
  meeting_url text,
  joining_instructions text,
  address text,
  pincode text
);

alter table event_private_details enable row level security;

create policy event_private_details_select on event_private_details for select
  using (
    exists (select 1 from events e where e.id = event_id and (e.host_id = auth.uid() or is_admin(auth.uid())))
    or exists (select 1 from event_attendees a where a.event_id = event_private_details.event_id and a.profile_id = auth.uid())
  );
create policy event_private_details_write on event_private_details for all
  using (exists (select 1 from events e where e.id = event_id and (e.host_id = auth.uid() or is_admin(auth.uid()))))
  with check (exists (select 1 from events e where e.id = event_id and (e.host_id = auth.uid() or is_admin(auth.uid()))));

-- ============================================================================
-- event_tags: reuses the existing `skills` catalog as event topics (spec:
-- "AI, Web Development, Cybersecurity, ...") rather than inventing a
-- parallel tag system — mirrors job_required_skills exactly.
-- ============================================================================

create table event_tags (
  event_id uuid not null references events(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete cascade,
  primary key (event_id, skill_id)
);

-- ============================================================================
-- event_agenda_items
-- ============================================================================

create table event_agenda_items (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  title text not null,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  speaker_profile_id uuid references profiles(id) on delete set null,
  speaker_name text,
  room text,
  sort_order integer not null default 0
);

create index event_agenda_items_event_idx on event_agenda_items(event_id, sort_order);

-- ============================================================================
-- event_speakers — links to a real Communeo profile where the speaker has
-- one; name/role/company/bio are free text for external speakers who
-- don't, or to caption a linked profile for this event specifically
-- without editing their actual profile.
-- ============================================================================

create table event_speakers (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  profile_id uuid references profiles(id) on delete set null,
  name text,
  role text,
  company text,
  bio text,
  sort_order integer not null default 0,
  constraint event_speakers_identified check (profile_id is not null or name is not null)
);

create index event_speakers_event_idx on event_speakers(event_id, sort_order);

alter table event_tags enable row level security;
alter table event_agenda_items enable row level security;
alter table event_speakers enable row level security;

create policy event_tags_select on event_tags for select using (true);
create policy event_tags_write on event_tags for all
  using (exists (select 1 from events e where e.id = event_id and (e.host_id = auth.uid() or is_admin(auth.uid()))))
  with check (exists (select 1 from events e where e.id = event_id and (e.host_id = auth.uid() or is_admin(auth.uid()))));

create policy event_agenda_items_select on event_agenda_items for select using (true);
create policy event_agenda_items_write on event_agenda_items for all
  using (exists (select 1 from events e where e.id = event_id and (e.host_id = auth.uid() or is_admin(auth.uid()))))
  with check (exists (select 1 from events e where e.id = event_id and (e.host_id = auth.uid() or is_admin(auth.uid()))));

create policy event_speakers_select on event_speakers for select using (true);
create policy event_speakers_write on event_speakers for all
  using (exists (select 1 from events e where e.id = event_id and (e.host_id = auth.uid() or is_admin(auth.uid()))))
  with check (exists (select 1 from events e where e.id = event_id and (e.host_id = auth.uid() or is_admin(auth.uid()))));

-- ============================================================================
-- event_join_requests — the invite-only path. Mirrors
-- hackathon_team_join_requests (0026) exactly: no direct client
-- insert/update, every state transition goes through the SECURITY DEFINER
-- functions below so capacity/visibility/duplicate checks and the matching
-- notification always happen atomically together.
-- ============================================================================

create table event_join_requests (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  requester_id uuid not null references profiles(id) on delete cascade,
  status invitation_status not null default 'pending',
  message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index event_join_requests_event_idx on event_join_requests(event_id);
create index event_join_requests_requester_idx on event_join_requests(requester_id);

create unique index event_join_requests_pending_unique
  on event_join_requests(event_id, requester_id)
  where status = 'pending';

alter table event_join_requests enable row level security;

create policy event_join_requests_select on event_join_requests for select
  using (
    requester_id = auth.uid()
    or exists (select 1 from events e where e.id = event_id and (e.host_id = auth.uid() or is_admin(auth.uid())))
  );
-- No client insert/update/delete — see join_event()/respond_to_event_join_request() below.

create trigger set_updated_at before update on event_join_requests
  for each row execute function handle_updated_at();

-- Lock down direct client inserts now that registering goes through
-- join_event() below — a raw insert could skip the capacity/deadline/
-- visibility checks and the invite-only request path entirely. Self-service
-- cancellation (delete your own row) needs no special validation, so it
-- stays a plain policy exactly as before.
drop policy if exists event_attendees_write on event_attendees;
create policy event_attendees_delete_own on event_attendees for delete
  using (profile_id = auth.uid());

-- ============================================================================
-- Helpers
-- ============================================================================

create or replace function event_attendee_count(p_event_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer from event_attendees where event_id = p_event_id;
$$;

create or replace function is_connected(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from connections
    where status = 'accepted'
      and ((requester_id = a and receiver_id = b) or (requester_id = b and receiver_id = a))
  );
$$;

-- ============================================================================
-- join_event: registers the caller directly for public/connections events
-- with room left, or files an event_join_requests row for invite-only
-- ones. Returns 'registered' or 'requested' so the client knows which
-- happened. All the checks the old bare `insert into event_attendees`
-- couldn't make (capacity, deadline, visibility, duplicates) now happen
-- atomically with the write.
-- ============================================================================

create or replace function join_event(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_event events%rowtype;
  v_requester_name text;
begin
  if v_caller is null then
    raise exception 'not authenticated';
  end if;

  select * into v_event from events where id = p_event_id for update;
  if v_event is null then
    raise exception 'event not found';
  end if;
  if v_event.status = 'cancelled' then
    raise exception 'this event has been cancelled';
  end if;
  if v_event.host_id = v_caller then
    raise exception 'you are hosting this event';
  end if;
  if exists (select 1 from event_attendees where event_id = p_event_id and profile_id = v_caller) then
    raise exception 'you are already registered for this event';
  end if;
  if v_event.registration_deadline is not null and now() > v_event.registration_deadline then
    raise exception 'registration for this event has closed';
  end if;
  if v_event.max_participants is not null and event_attendee_count(p_event_id) >= v_event.max_participants then
    raise exception 'this event is full';
  end if;
  if v_event.visibility = 'connections' and not is_connected(v_caller, v_event.host_id) then
    raise exception 'this event is open to the host''s connections only';
  end if;

  select full_name into v_requester_name from profiles where id = v_caller;

  if v_event.visibility = 'invite_only' then
    if exists (select 1 from event_join_requests where event_id = p_event_id and requester_id = v_caller and status = 'pending') then
      raise exception 'you already have a pending request for this event';
    end if;
    insert into event_join_requests (event_id, requester_id) values (p_event_id, v_caller);
    insert into notifications (profile_id, type, title, body, data)
    values (
      v_event.host_id,
      'event_join_request',
      'New event join request',
      coalesce(v_requester_name, 'Someone') || ' asked to join "' || v_event.title || '".',
      jsonb_build_object('event_id', p_event_id, 'event_title', v_event.title, 'requester_id', v_caller)
    );
    return 'requested';
  end if;

  insert into event_attendees (event_id, profile_id) values (p_event_id, v_caller);
  insert into notifications (profile_id, type, title, body, data)
  values (
    v_event.host_id,
    'event_registration',
    'New event registration',
    coalesce(v_requester_name, 'Someone') || ' registered for "' || v_event.title || '".',
    jsonb_build_object('event_id', p_event_id, 'event_title', v_event.title, 'attendee_id', v_caller)
  );
  return 'registered';
end;
$$;

-- ============================================================================
-- respond_to_event_join_request: host-only accept/decline.
-- ============================================================================

create or replace function respond_to_event_join_request(p_request_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_request event_join_requests%rowtype;
  v_event events%rowtype;
begin
  if v_caller is null then
    raise exception 'not authenticated';
  end if;

  select * into v_request from event_join_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'request not found';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'this request has already been responded to';
  end if;

  select * into v_event from events where id = v_request.event_id for update;
  if v_event.host_id <> v_caller and not is_admin(v_caller) then
    raise exception 'only the host can respond to join requests';
  end if;

  if not p_accept then
    update event_join_requests set status = 'rejected' where id = p_request_id;
    insert into notifications (profile_id, type, title, body, data)
    values (
      v_request.requester_id,
      'event_join_request_declined',
      'Join request declined',
      'Your request to join "' || v_event.title || '" was declined.',
      jsonb_build_object('event_id', v_event.id, 'event_title', v_event.title)
    );
    return;
  end if;

  if v_event.max_participants is not null and event_attendee_count(v_event.id) >= v_event.max_participants then
    raise exception 'this event is full';
  end if;

  update event_join_requests set status = 'accepted' where id = p_request_id;
  insert into event_attendees (event_id, profile_id) values (v_event.id, v_request.requester_id)
  on conflict do nothing;
  insert into notifications (profile_id, type, title, body, data)
  values (
    v_request.requester_id,
    'event_join_request_accepted',
    'Join request accepted',
    'You''re in! Your request to join "' || v_event.title || '" was accepted.',
    jsonb_build_object('event_id', v_event.id, 'event_title', v_event.title)
  );
end;
$$;

-- ============================================================================
-- cancel_event: host/admin only. Notifies every current attendee.
-- ============================================================================

create or replace function cancel_event(p_event_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_event events%rowtype;
  v_attendee record;
begin
  if v_caller is null then
    raise exception 'not authenticated';
  end if;

  select * into v_event from events where id = p_event_id for update;
  if v_event is null then
    raise exception 'event not found';
  end if;
  if v_event.host_id <> v_caller and not is_admin(v_caller) then
    raise exception 'only the host can cancel this event';
  end if;
  if v_event.status = 'cancelled' then
    raise exception 'this event is already cancelled';
  end if;

  update events set status = 'cancelled', cancelled_at = now(), cancellation_reason = p_reason
  where id = p_event_id;

  for v_attendee in select profile_id from event_attendees where event_id = p_event_id loop
    insert into notifications (profile_id, type, title, body, data)
    values (
      v_attendee.profile_id,
      'event_cancelled',
      'Event cancelled',
      '"' || v_event.title || '" has been cancelled.' || coalesce(' Reason: ' || p_reason, ''),
      jsonb_build_object('event_id', p_event_id, 'event_title', v_event.title)
    );
  end loop;
end;
$$;

create trigger set_updated_at_events before update on events
  for each row execute function handle_updated_at();
