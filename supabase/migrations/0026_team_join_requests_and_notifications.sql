-- 0026_team_join_requests_and_notifications.sql
-- Bidirectional hackathon team formation. Team owners could already invite
-- (team_invitations, existing) but nothing notified the invitee, and there
-- was no reverse direction (a participant requesting to join an existing
-- team) or an explicit membership table — the old schema only inferred
-- membership from accepted-invitation rows, which doesn't generalize once
-- join requests need to write to the same source of truth. All state
-- transitions below go through SECURITY DEFINER functions rather than raw
-- client writes, so capacity/one-team-per-hackathon/duplicate checks and
-- the matching notification are always created atomically together.

-- ============================================================================
-- Membership — the missing single source of truth
-- ============================================================================

create table hackathon_team_members (
  id uuid primary key default gen_random_uuid(),
  team_requirement_id uuid not null references hackathon_team_requirements(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  constraint hackathon_team_members_unique unique (team_requirement_id, profile_id)
);

create index hackathon_team_members_team_idx on hackathon_team_members(team_requirement_id);
create index hackathon_team_members_profile_idx on hackathon_team_members(profile_id);

alter table hackathon_team_members enable row level security;
create policy hackathon_team_members_select on hackathon_team_members for select using (true);
-- The one client-side write allowed: a team's creator adding themselves as
-- its first member at creation time (can't be abused to add anyone else,
-- or to join a team they don't own). Every other membership change —
-- accepting an invitation or a join request — goes through the SECURITY
-- DEFINER functions below instead, since those also need the
-- capacity/one-team-per-hackathon checks a raw insert could race past.
create policy hackathon_team_members_insert_creator on hackathon_team_members for insert
  with check (
    profile_id = auth.uid()
    and exists (select 1 from hackathon_team_requirements r where r.id = team_requirement_id and r.creator_id = auth.uid())
  );
-- No client update/delete at all.

-- Backfill: a team's creator always implicitly counted as its first member.
insert into hackathon_team_members (team_requirement_id, profile_id)
select id, creator_id from hackathon_team_requirements
on conflict do nothing;

-- Backfill: anyone with an already-accepted invitation is already a member.
insert into hackathon_team_members (team_requirement_id, profile_id)
select team_requirement_id, receiver_id from team_invitations where status = 'accepted'
on conflict do nothing;

-- ============================================================================
-- Join requests — the direction the schema was missing
-- ============================================================================

create table hackathon_team_join_requests (
  id uuid primary key default gen_random_uuid(),
  team_requirement_id uuid not null references hackathon_team_requirements(id) on delete cascade,
  requester_id uuid not null references profiles(id) on delete cascade,
  status invitation_status not null default 'pending',
  message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index hackathon_team_join_requests_team_idx on hackathon_team_join_requests(team_requirement_id);
create index hackathon_team_join_requests_requester_idx on hackathon_team_join_requests(requester_id);

-- Only one PENDING request per requester per team — re-requesting after a
-- rejection/cancellation is fine (a fresh row); duplicate pending ones are not.
create unique index hackathon_team_join_requests_pending_unique
  on hackathon_team_join_requests(team_requirement_id, requester_id)
  where status = 'pending';

alter table hackathon_team_join_requests enable row level security;
create policy hackathon_team_join_requests_select on hackathon_team_join_requests for select
  using (
    requester_id = auth.uid()
    or exists (select 1 from hackathon_team_requirements r where r.id = team_requirement_id and r.creator_id = auth.uid())
  );
-- No client insert/update here either — see the functions below.

create trigger set_updated_at before update on hackathon_team_join_requests
  for each row execute function handle_updated_at();

-- Lock down direct client writes to team_invitations status now that
-- accept/reject goes through respond_to_team_invitation() below — a raw
-- client update could mark one "accepted" without the matching membership
-- row, capacity check, or notification.
drop policy if exists team_invitations_update on team_invitations;

-- ============================================================================
-- Helpers
-- ============================================================================

create or replace function hackathon_team_member_count(p_team_requirement_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer from hackathon_team_members where team_requirement_id = p_team_requirement_id;
$$;

-- Which team (if any) a profile already belongs to within a given
-- hackathon — the enforcement point for "one team per hackathon".
create or replace function hackathon_team_of(p_profile_id uuid, p_hackathon_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select m.team_requirement_id
  from hackathon_team_members m
  join hackathon_team_requirements r on r.id = m.team_requirement_id
  where m.profile_id = p_profile_id and r.hackathon_id = p_hackathon_id
  limit 1;
$$;

-- ============================================================================
-- Invitations: team owner -> user (send / respond), now with notifications
-- ============================================================================

create or replace function send_team_invitation(
  p_team_requirement_id uuid,
  p_receiver_id uuid,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team hackathon_team_requirements%rowtype;
  v_hackathon_name text;
  v_sender_name text;
  v_invitation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_team from hackathon_team_requirements where id = p_team_requirement_id for update;
  if v_team is null then
    raise exception 'team not found';
  end if;
  if v_team.creator_id <> auth.uid() then
    raise exception 'only the team owner can send invitations';
  end if;
  if p_receiver_id = auth.uid() then
    raise exception 'cannot invite yourself';
  end if;
  if v_team.status <> 'open' then
    raise exception 'this team is not open for new members';
  end if;
  if exists (select 1 from hackathon_team_members where team_requirement_id = p_team_requirement_id and profile_id = p_receiver_id) then
    raise exception 'this person is already on the team';
  end if;
  if exists (
    select 1 from team_invitations
    where team_requirement_id = p_team_requirement_id and receiver_id = p_receiver_id and status = 'pending'
  ) then
    raise exception 'an invitation to this person is already pending';
  end if;
  if hackathon_team_member_count(p_team_requirement_id) >= v_team.team_size then
    raise exception 'this team is full';
  end if;
  if hackathon_team_of(p_receiver_id, v_team.hackathon_id) is not null then
    raise exception 'this person is already on another team for this hackathon';
  end if;

  insert into team_invitations (team_requirement_id, sender_id, receiver_id, message)
  values (p_team_requirement_id, auth.uid(), p_receiver_id, p_message)
  returning id into v_invitation_id;

  select name into v_hackathon_name from hackathons where id = v_team.hackathon_id;
  select full_name into v_sender_name from profiles where id = auth.uid();

  insert into notifications (profile_id, type, title, body, data)
  values (
    p_receiver_id,
    'team_invitation',
    'Team invitation',
    coalesce(v_sender_name, 'Someone') || ' invited you to join "' || v_team.team_name || '" for ' || coalesce(v_hackathon_name, 'a hackathon') || '.',
    jsonb_build_object(
      'invitation_id', v_invitation_id,
      'team_requirement_id', p_team_requirement_id,
      'team_name', v_team.team_name,
      'hackathon_id', v_team.hackathon_id,
      'hackathon_name', v_hackathon_name,
      'sender_id', auth.uid()
    )
  );

  return v_invitation_id;
end;
$$;

create or replace function respond_to_team_invitation(p_invitation_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invitation team_invitations%rowtype;
  v_team hackathon_team_requirements%rowtype;
  v_hackathon_name text;
  v_receiver_name text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_invitation from team_invitations where id = p_invitation_id for update;
  if v_invitation is null then
    raise exception 'invitation not found';
  end if;
  if v_invitation.receiver_id <> auth.uid() then
    raise exception 'not your invitation to respond to';
  end if;
  if v_invitation.status <> 'pending' then
    raise exception 'this invitation has already been responded to';
  end if;

  select * into v_team from hackathon_team_requirements where id = v_invitation.team_requirement_id for update;
  select name into v_hackathon_name from hackathons where id = v_team.hackathon_id;
  select full_name into v_receiver_name from profiles where id = auth.uid();

  if not p_accept then
    update team_invitations set status = 'rejected' where id = p_invitation_id;
    insert into notifications (profile_id, type, title, body, data)
    values (
      v_invitation.sender_id,
      'team_invitation_declined',
      'Invitation declined',
      coalesce(v_receiver_name, 'Someone') || ' declined your invitation to join "' || v_team.team_name || '".',
      jsonb_build_object('team_requirement_id', v_team.id, 'team_name', v_team.team_name)
    );
    return;
  end if;

  if v_team.status <> 'open' then
    raise exception 'this team is no longer open';
  end if;
  if exists (select 1 from hackathon_team_members where team_requirement_id = v_team.id and profile_id = auth.uid()) then
    raise exception 'you are already on this team';
  end if;
  if hackathon_team_member_count(v_team.id) >= v_team.team_size then
    raise exception 'this team is full';
  end if;
  if hackathon_team_of(auth.uid(), v_team.hackathon_id) is not null then
    raise exception 'you are already on another team for this hackathon';
  end if;

  update team_invitations set status = 'accepted' where id = p_invitation_id;
  insert into hackathon_team_members (team_requirement_id, profile_id) values (v_team.id, auth.uid());

  if hackathon_team_member_count(v_team.id) >= v_team.team_size then
    update hackathon_team_requirements set status = 'full' where id = v_team.id;
  end if;

  -- The caller can only be on one team now — withdraw their other pending
  -- invitations/join-requests for the same hackathon so they don't linger
  -- as actionable notifications for something that's no longer possible.
  update team_invitations set status = 'cancelled'
    where receiver_id = auth.uid() and status = 'pending' and id <> p_invitation_id
      and team_requirement_id in (select id from hackathon_team_requirements where hackathon_id = v_team.hackathon_id);
  update hackathon_team_join_requests set status = 'cancelled'
    where requester_id = auth.uid() and status = 'pending'
      and team_requirement_id in (select id from hackathon_team_requirements where hackathon_id = v_team.hackathon_id);

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_invitation.sender_id,
    'team_invitation_accepted',
    'Invitation accepted',
    coalesce(v_receiver_name, 'Someone') || ' accepted your invitation and joined "' || v_team.team_name || '".',
    jsonb_build_object('team_requirement_id', v_team.id, 'team_name', v_team.team_name, 'hackathon_id', v_team.hackathon_id)
  );
end;
$$;

-- ============================================================================
-- Join requests: user -> team owner (request / respond)
-- ============================================================================

create or replace function request_to_join_team(p_team_requirement_id uuid, p_message text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team hackathon_team_requirements%rowtype;
  v_hackathon_name text;
  v_requester_name text;
  v_request_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_team from hackathon_team_requirements where id = p_team_requirement_id for update;
  if v_team is null then
    raise exception 'team not found';
  end if;
  if v_team.creator_id = auth.uid() then
    raise exception 'you already own this team';
  end if;
  if v_team.status <> 'open' then
    raise exception 'this team is not open for new members';
  end if;
  if exists (select 1 from hackathon_team_members where team_requirement_id = p_team_requirement_id and profile_id = auth.uid()) then
    raise exception 'you are already on this team';
  end if;
  if exists (
    select 1 from hackathon_team_join_requests
    where team_requirement_id = p_team_requirement_id and requester_id = auth.uid() and status = 'pending'
  ) then
    raise exception 'you already have a pending request for this team';
  end if;
  if hackathon_team_member_count(p_team_requirement_id) >= v_team.team_size then
    raise exception 'this team is full';
  end if;
  if hackathon_team_of(auth.uid(), v_team.hackathon_id) is not null then
    raise exception 'you are already on another team for this hackathon';
  end if;

  insert into hackathon_team_join_requests (team_requirement_id, requester_id, message)
  values (p_team_requirement_id, auth.uid(), p_message)
  returning id into v_request_id;

  select name into v_hackathon_name from hackathons where id = v_team.hackathon_id;
  select full_name into v_requester_name from profiles where id = auth.uid();

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_team.creator_id,
    'team_join_request',
    'New join request',
    coalesce(v_requester_name, 'Someone') || ' wants to join your team "' || v_team.team_name || '" for ' || coalesce(v_hackathon_name, 'a hackathon') || '.',
    jsonb_build_object(
      'request_id', v_request_id,
      'team_requirement_id', p_team_requirement_id,
      'team_name', v_team.team_name,
      'hackathon_id', v_team.hackathon_id,
      'hackathon_name', v_hackathon_name,
      'requester_id', auth.uid()
    )
  );

  return v_request_id;
end;
$$;

create or replace function respond_to_join_request(p_request_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request hackathon_team_join_requests%rowtype;
  v_team hackathon_team_requirements%rowtype;
  v_hackathon_name text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_request from hackathon_team_join_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'request not found';
  end if;

  select * into v_team from hackathon_team_requirements where id = v_request.team_requirement_id for update;
  if v_team.creator_id <> auth.uid() then
    raise exception 'only the team owner can respond to this request';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'this request has already been responded to';
  end if;

  select name into v_hackathon_name from hackathons where id = v_team.hackathon_id;

  if not p_accept then
    update hackathon_team_join_requests set status = 'rejected' where id = p_request_id;
    insert into notifications (profile_id, type, title, body, data)
    values (
      v_request.requester_id,
      'team_join_request_rejected',
      'Join request declined',
      'Your request to join "' || v_team.team_name || '" was declined.',
      jsonb_build_object('team_requirement_id', v_team.id, 'team_name', v_team.team_name)
    );
    return;
  end if;

  if v_team.status <> 'open' then
    raise exception 'this team is no longer open';
  end if;
  if exists (select 1 from hackathon_team_members where team_requirement_id = v_team.id and profile_id = v_request.requester_id) then
    raise exception 'this person is already on the team';
  end if;
  if hackathon_team_member_count(v_team.id) >= v_team.team_size then
    raise exception 'this team is full';
  end if;
  if hackathon_team_of(v_request.requester_id, v_team.hackathon_id) is not null then
    raise exception 'this person is already on another team for this hackathon';
  end if;

  update hackathon_team_join_requests set status = 'accepted' where id = p_request_id;
  insert into hackathon_team_members (team_requirement_id, profile_id) values (v_team.id, v_request.requester_id);

  if hackathon_team_member_count(v_team.id) >= v_team.team_size then
    update hackathon_team_requirements set status = 'full' where id = v_team.id;
  end if;

  update team_invitations set status = 'cancelled'
    where receiver_id = v_request.requester_id and status = 'pending' and team_requirement_id <> v_team.id
      and team_requirement_id in (select id from hackathon_team_requirements where hackathon_id = v_team.hackathon_id);
  update hackathon_team_join_requests set status = 'cancelled'
    where requester_id = v_request.requester_id and status = 'pending' and id <> p_request_id
      and team_requirement_id in (select id from hackathon_team_requirements where hackathon_id = v_team.hackathon_id);

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_request.requester_id,
    'team_join_request_accepted',
    'Join request accepted',
    'Your request to join "' || v_team.team_name || '" has been accepted.',
    jsonb_build_object('team_requirement_id', v_team.id, 'team_name', v_team.team_name, 'hackathon_id', v_team.hackathon_id)
  );
end;
$$;

create or replace function cancel_join_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  update hackathon_team_join_requests
  set status = 'cancelled'
  where id = p_request_id and requester_id = auth.uid() and status = 'pending';
end;
$$;

-- ============================================================================
-- Realtime: notifications deliver every event above live (spec section 7)
-- ============================================================================

alter publication supabase_realtime add table notifications;
