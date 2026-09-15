-- 0028_team_management.sql
-- Team management: leave team, view members, member profiles, a private
-- team group chat, and delete team (owner-only) — spec sections 1-8.
--
-- "Team" here is `hackathon_team_requirements` (the only team concept the
-- app has); membership is `hackathon_team_members` (0026). Chat is not a
-- new subsystem: it reuses the existing `conversations` / `conversation_members`
-- / `messages` tables (already realtime-enabled, already RLS'd generically
-- via `is_conversation_member`) by adding a `team_requirement_id` link and a
-- new `conversation_type` value, exactly like direct conversations already
-- work. All membership-affecting writes (join, leave, delete) go through
-- SECURITY DEFINER functions so the chat-access side effect can never be
-- forgotten or done out of order by a client.

-- ============================================================================
-- Schema: team-linked conversations
-- ============================================================================
-- (conversation_type's 'team' value was added in 0027, which also converted
-- the column from a native enum to text+check — see that file for why.)

alter table conversations
  add column if not exists team_requirement_id uuid references hackathon_team_requirements(id) on delete cascade;

-- At most one chat per team; also the lookup index for team_conversation_id().
create unique index if not exists conversations_team_requirement_idx
  on conversations(team_requirement_id) where team_requirement_id is not null;

-- ============================================================================
-- Helpers
-- ============================================================================

create or replace function team_conversation_id(p_team_requirement_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from conversations where team_requirement_id = p_team_requirement_id limit 1;
$$;

-- ============================================================================
-- Chat creation (called once, right after a team requirement is created)
-- ============================================================================

create or replace function create_team_conversation(p_team_requirement_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team hackathon_team_requirements%rowtype;
  v_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_team from hackathon_team_requirements where id = p_team_requirement_id;
  if v_team is null then
    raise exception 'team not found';
  end if;
  if v_team.creator_id <> auth.uid() then
    raise exception 'only the team creator can initialize its chat';
  end if;

  v_conversation_id := team_conversation_id(p_team_requirement_id);
  if v_conversation_id is not null then
    return v_conversation_id;
  end if;

  insert into conversations (conversation_type, team_requirement_id)
  values ('team', p_team_requirement_id)
  returning id into v_conversation_id;

  insert into conversation_members (conversation_id, profile_id)
  values (v_conversation_id, auth.uid())
  on conflict do nothing;

  return v_conversation_id;
end;
$$;

-- ============================================================================
-- Joining a team now also grants chat access, atomically. Redefines the two
-- 0026 accept paths (invitation / join request) to add the extra insert.
-- ============================================================================

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
  v_conversation_id uuid;
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

  v_conversation_id := team_conversation_id(v_team.id);
  if v_conversation_id is not null then
    insert into conversation_members (conversation_id, profile_id)
    values (v_conversation_id, auth.uid())
    on conflict do nothing;
  end if;

  if hackathon_team_member_count(v_team.id) >= v_team.team_size then
    update hackathon_team_requirements set status = 'full' where id = v_team.id;
  end if;

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
  v_conversation_id uuid;
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

  v_conversation_id := team_conversation_id(v_team.id);
  if v_conversation_id is not null then
    insert into conversation_members (conversation_id, profile_id)
    values (v_conversation_id, v_request.requester_id)
    on conflict do nothing;
  end if;

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

-- ============================================================================
-- Leave team (spec section 1) — a member-only action; the owner deletes
-- instead (see delete_team_requirement below) rather than "leaving" a team
-- they'd otherwise orphan.
-- ============================================================================

create or replace function leave_team(p_team_requirement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team hackathon_team_requirements%rowtype;
  v_conversation_id uuid;
  v_leaver_name text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_team from hackathon_team_requirements where id = p_team_requirement_id for update;
  if v_team is null then
    raise exception 'team not found';
  end if;
  if v_team.creator_id = auth.uid() then
    raise exception 'the team owner cannot leave — delete the team instead';
  end if;
  if not exists (
    select 1 from hackathon_team_members where team_requirement_id = p_team_requirement_id and profile_id = auth.uid()
  ) then
    raise exception 'you are not a member of this team';
  end if;

  delete from hackathon_team_members
    where team_requirement_id = p_team_requirement_id and profile_id = auth.uid();

  v_conversation_id := team_conversation_id(p_team_requirement_id);
  if v_conversation_id is not null then
    delete from conversation_members
      where conversation_id = v_conversation_id and profile_id = auth.uid();
  end if;

  -- A slot just opened up; a team that was full is open again.
  if v_team.status = 'full' then
    update hackathon_team_requirements set status = 'open' where id = p_team_requirement_id;
  end if;

  select full_name into v_leaver_name from profiles where id = auth.uid();
  insert into notifications (profile_id, type, title, body, data)
  values (
    v_team.creator_id,
    'team_member_left',
    'A member left your team',
    coalesce(v_leaver_name, 'Someone') || ' left "' || v_team.team_name || '".',
    jsonb_build_object('team_requirement_id', v_team.id, 'team_name', v_team.team_name, 'hackathon_id', v_team.hackathon_id)
  );
end;
$$;

-- ============================================================================
-- Delete team (spec section 6) — owner-only. Cascades (hackathon_team_members,
-- hackathon_team_required_skills, team_invitations, hackathon_team_join_requests,
-- and now conversations -> conversation_members -> messages/message_reactions)
-- are all already `on delete cascade`, so no orphaned records remain. The
-- existing hackathon_team_requirements_delete RLS policy (creator or admin)
-- stays as defense-in-depth; this function re-checks ownership itself since,
-- as SECURITY DEFINER, it does not go through RLS.
-- ============================================================================

create or replace function delete_team_requirement(p_team_requirement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team hackathon_team_requirements%rowtype;
  v_member record;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_team from hackathon_team_requirements where id = p_team_requirement_id for update;
  if v_team is null then
    raise exception 'team not found';
  end if;
  if v_team.creator_id <> auth.uid() and not is_admin(auth.uid()) then
    raise exception 'only the team owner can delete this team';
  end if;

  for v_member in
    select profile_id from hackathon_team_members
    where team_requirement_id = p_team_requirement_id and profile_id <> v_team.creator_id
  loop
    insert into notifications (profile_id, type, title, body, data)
    values (
      v_member.profile_id,
      'team_deleted',
      'Team deleted',
      '"' || v_team.team_name || '" was deleted by its owner.',
      jsonb_build_object('team_name', v_team.team_name, 'hackathon_id', v_team.hackathon_id)
    );
  end loop;

  delete from hackathon_team_requirements where id = p_team_requirement_id;
end;
$$;

-- ============================================================================
-- Backfill: teams created before this migration get a chat too.
-- ============================================================================

insert into conversations (conversation_type, team_requirement_id)
select 'team', r.id
from hackathon_team_requirements r
where not exists (select 1 from conversations c where c.team_requirement_id = r.id);

insert into conversation_members (conversation_id, profile_id)
select c.id, m.profile_id
from hackathon_team_members m
join conversations c on c.team_requirement_id = m.team_requirement_id
on conflict do nothing;
