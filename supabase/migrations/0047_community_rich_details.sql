-- 0047_community_rich_details.sql
-- Communities only ever collected name/description/type — no way to
-- understand a community before joining, no join-approval flow (a private
-- community's `community_members_insert` policy never actually checked
-- privacy), no pre-join Q&A, and no group chat. This adds all of that,
-- reusing the exact patterns already established for hackathon teams
-- (0026/0028/0046_*.sql): a join-request table, SECURITY DEFINER RPCs as
-- the only membership-mutating path, and a conversations.<parent>_id link
-- for group chat.
--
-- Every new column is nullable/defaulted so every existing community row
-- keeps working unchanged — see community_test.dart's backward-compat
-- coverage. Existing tables (communities' original fields, community_members,
-- community_posts, community_comments) are reused as-is, not duplicated.

-- ============================================================================
-- Enums
-- ============================================================================

create type community_access_type as enum ('public', 'request_to_join', 'private');

-- community_type was already a native enum (0002_enums.sql: 'technology',
-- 'city', 'student', 'startup', 'research', 'open_source', 'interest_based')
-- — additive only, so every existing community keeps its exact type. New
-- values match this task's suggested type list; 'startup'/'technology'/
-- 'interest_based' already existed and are reused as-is.
alter type community_type add value if not exists 'professional';
alter type community_type add value if not exists 'career';
alter type community_type add value if not exists 'college';
alter type community_type add value if not exists 'local';
alter type community_type add value if not exists 'project';
alter type community_type add value if not exists 'learning';
alter type community_type add value if not exists 'other';

-- ============================================================================
-- communities: new columns
-- ============================================================================

alter table communities
  add column tagline text,
  add column logo_url text,
  add column activities text[] not null default '{}',
  add column audience text[] not null default '{}',
  add column rules text,
  add column access_type community_access_type not null default 'public';

-- Backfill from the existing is_private boolean. is_private stays a real,
-- app-maintained column (existing RLS on community_members/community_posts/
-- community_comments already keys off it, see 0019_rls.sql, and keeps
-- working unmodified) — the app sets both columns together going forward:
-- is_private = (access_type = 'private'); a 'request_to_join' community is
-- still publicly *discoverable*, only joining requires approval.
update communities set access_type = (case when is_private then 'private' else 'public' end)::community_access_type;

-- ============================================================================
-- community_topics — reuses the existing global `skills` table (spec:
-- "reuse Communeo's existing skills/topics/tag system", not a new
-- taxonomy). Identical shape/RLS to hackathon_team_required_skills.
-- ============================================================================

create table community_topics (
  community_id uuid not null references communities(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete cascade,
  primary key (community_id, skill_id)
);

alter table community_topics enable row level security;
create policy community_topics_select on community_topics for select using (true);
create policy community_topics_write on community_topics for all
  using (exists (select 1 from communities c where c.id = community_id and c.owner_id = auth.uid()))
  with check (exists (select 1 from communities c where c.id = community_id and c.owner_id = auth.uid()));

-- ============================================================================
-- community_join_requests — the approval-gated join direction the schema
-- never had (direct community_members inserts were the only path, and
-- community_members_insert never actually checked privacy). Mirrors
-- hackathon_team_join_requests exactly.
-- ============================================================================

create table community_join_requests (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities(id) on delete cascade,
  requester_id uuid not null references profiles(id) on delete cascade,
  status invitation_status not null default 'pending',
  message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index community_join_requests_community_idx on community_join_requests(community_id);
create index community_join_requests_requester_idx on community_join_requests(requester_id);

create unique index community_join_requests_pending_unique
  on community_join_requests(community_id, requester_id)
  where status = 'pending';

alter table community_join_requests enable row level security;
create policy community_join_requests_select on community_join_requests for select
  using (
    requester_id = auth.uid()
    or exists (select 1 from communities c where c.id = community_id and c.owner_id = auth.uid())
  );
-- No client insert/update — see request_to_join_community() etc. below.

create trigger set_updated_at before update on community_join_requests
  for each row execute function handle_updated_at();

-- ============================================================================
-- Pre-join Q&A — genuinely new: nothing like it existed. A non-member who
-- can see the community can ask; only members/moderators/the owner can
-- answer (they're all rows in community_members, so is_community_member()
-- covers all three).
-- ============================================================================

create table community_questions (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities(id) on delete cascade,
  asker_id uuid not null references profiles(id) on delete cascade,
  question_text text not null,
  created_at timestamptz not null default now()
);

create index community_questions_community_idx on community_questions(community_id, created_at desc);

alter table community_questions enable row level security;
create policy community_questions_select on community_questions for select
  using (exists (
    select 1 from communities c where c.id = community_id and (c.is_private = false or is_community_member(c.id, auth.uid()))
  ));
create policy community_questions_insert on community_questions for insert
  with check (
    asker_id = auth.uid()
    and exists (
      select 1 from communities c
      where c.id = community_id
        and (c.is_private = false or is_community_member(c.id, auth.uid()))
        and not is_blocked(auth.uid(), c.owner_id)
    )
  );

create table community_answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references community_questions(id) on delete cascade,
  responder_id uuid not null references profiles(id) on delete cascade,
  answer_text text not null,
  created_at timestamptz not null default now()
);

create index community_answers_question_idx on community_answers(question_id, created_at);

alter table community_answers enable row level security;
create policy community_answers_select on community_answers for select
  using (exists (
    select 1 from community_questions q join communities c on c.id = q.community_id
    where q.id = question_id and (c.is_private = false or is_community_member(c.id, auth.uid()))
  ));
-- Members/moderators/owner only — spec: "non-members should NOT be able to
-- answer questions".
create policy community_answers_insert on community_answers for insert
  with check (
    responder_id = auth.uid()
    and exists (
      select 1 from community_questions q where q.id = question_id and is_community_member(q.community_id, auth.uid())
    )
  );

-- ============================================================================
-- Announcements reuse community_posts (spec: "do not create duplicate
-- posting infrastructure") — just a flag, enforced to moderator/admin/owner
-- only via trigger since community_posts_insert's existing RLS only checks
-- plain membership.
-- ============================================================================

alter table community_posts add column is_announcement boolean not null default false;

create or replace function enforce_community_announcement_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role community_role;
begin
  if new.is_announcement then
    select role into v_role from community_members
      where community_id = new.community_id and profile_id = new.author_id;
    if v_role is null or v_role = 'member' then
      raise exception 'only community moderators/admins can post announcements';
    end if;
  end if;
  return new;
end;
$$;

create trigger community_posts_announcement_check
  before insert on community_posts
  for each row execute function enforce_community_announcement_role();

-- ============================================================================
-- Group chat — same pattern as hackathon teams (0027/0028): a
-- conversations.<parent>_id link plus SECURITY DEFINER helpers, not a new
-- messaging system.
-- ============================================================================

alter table conversations
  add column if not exists community_id uuid references communities(id) on delete cascade;

create unique index if not exists conversations_community_idx
  on conversations(community_id) where community_id is not null;

alter table conversations drop constraint if exists conversations_conversation_type_check;
alter table conversations add constraint conversations_conversation_type_check
  check (conversation_type in ('direct', 'team', 'community'));

create or replace function community_conversation_id(p_community_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from conversations where community_id = p_community_id limit 1;
$$;

create or replace function create_community_conversation(p_community_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_community communities%rowtype;
  v_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_community from communities where id = p_community_id;
  if v_community is null then
    raise exception 'community not found';
  end if;
  if v_community.owner_id <> auth.uid() then
    raise exception 'only the community owner can initialize its chat';
  end if;

  v_conversation_id := community_conversation_id(p_community_id);
  if v_conversation_id is not null then
    return v_conversation_id;
  end if;

  insert into conversations (conversation_type, community_id)
  values ('community', p_community_id)
  returning id into v_conversation_id;

  insert into conversation_members (conversation_id, profile_id)
  values (v_conversation_id, auth.uid())
  on conflict do nothing;

  return v_conversation_id;
end;
$$;

-- Backfill: communities created before this migration get a chat too, with
-- every existing member added.
insert into conversations (conversation_type, community_id)
select 'community', c.id
from communities c
where not exists (select 1 from conversations conv where conv.community_id = c.id);

insert into conversation_members (conversation_id, profile_id)
select conv.id, m.profile_id
from community_members m
join conversations conv on conv.community_id = m.community_id
on conflict do nothing;

-- ============================================================================
-- Membership RPCs. community_members_insert (below) is narrowed to public
-- communities only — request_to_join/private communities must go through
-- these functions instead, closing the gap where privacy was never
-- actually enforced at join time.
-- ============================================================================

drop policy if exists community_members_insert on community_members;
create policy community_members_insert on community_members for insert
  with check (
    profile_id = auth.uid()
    and exists (select 1 from communities c where c.id = community_id and c.access_type = 'public')
  );

create or replace function join_community(p_community_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_community communities%rowtype;
  v_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_community from communities where id = p_community_id for update;
  if v_community is null then
    raise exception 'community not found';
  end if;
  if v_community.access_type <> 'public' then
    raise exception 'this community requires a join request';
  end if;
  if exists (select 1 from community_members where community_id = p_community_id and profile_id = auth.uid()) then
    raise exception 'already a member';
  end if;
  if is_blocked(auth.uid(), v_community.owner_id) then
    raise exception 'unable to join this community';
  end if;

  insert into community_members (community_id, profile_id) values (p_community_id, auth.uid());

  v_conversation_id := community_conversation_id(p_community_id);
  if v_conversation_id is not null then
    insert into conversation_members (conversation_id, profile_id) values (v_conversation_id, auth.uid())
      on conflict do nothing;
  end if;
end;
$$;

create or replace function request_to_join_community(p_community_id uuid, p_message text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_community communities%rowtype;
  v_requester_name text;
  v_request_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_community from communities where id = p_community_id for update;
  if v_community is null then
    raise exception 'community not found';
  end if;
  if v_community.access_type <> 'request_to_join' then
    raise exception 'this community does not use join requests';
  end if;
  if v_community.owner_id = auth.uid() then
    raise exception 'you already own this community';
  end if;
  if exists (select 1 from community_members where community_id = p_community_id and profile_id = auth.uid()) then
    raise exception 'you are already a member';
  end if;
  if exists (
    select 1 from community_join_requests
    where community_id = p_community_id and requester_id = auth.uid() and status = 'pending'
  ) then
    raise exception 'you already have a pending request';
  end if;
  if is_blocked(auth.uid(), v_community.owner_id) then
    raise exception 'unable to request to join this community';
  end if;

  insert into community_join_requests (community_id, requester_id, message)
  values (p_community_id, auth.uid(), p_message)
  returning id into v_request_id;

  select full_name into v_requester_name from profiles where id = auth.uid();

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_community.owner_id,
    'community_join_request',
    'New join request',
    coalesce(v_requester_name, 'Someone') || ' requested to join "' || v_community.name || '".',
    jsonb_build_object('request_id', v_request_id, 'community_id', p_community_id, 'community_name', v_community.name, 'requester_id', auth.uid())
  );

  return v_request_id;
end;
$$;

create or replace function respond_to_community_join_request(p_request_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request community_join_requests%rowtype;
  v_community communities%rowtype;
  v_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_request from community_join_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'request not found';
  end if;

  select * into v_community from communities where id = v_request.community_id for update;
  if v_community.owner_id <> auth.uid() then
    raise exception 'only the community owner can respond to this request';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'this request has already been responded to';
  end if;

  if not p_accept then
    update community_join_requests set status = 'rejected' where id = p_request_id;
    insert into notifications (profile_id, type, title, body, data)
    values (
      v_request.requester_id,
      'community_join_request_rejected',
      'Join request declined',
      'Your request to join "' || v_community.name || '" was declined.',
      jsonb_build_object('community_id', v_community.id, 'community_name', v_community.name)
    );
    return;
  end if;

  if exists (select 1 from community_members where community_id = v_community.id and profile_id = v_request.requester_id) then
    raise exception 'this person is already a member';
  end if;

  update community_join_requests set status = 'accepted' where id = p_request_id;
  insert into community_members (community_id, profile_id) values (v_community.id, v_request.requester_id);

  v_conversation_id := community_conversation_id(v_community.id);
  if v_conversation_id is not null then
    insert into conversation_members (conversation_id, profile_id) values (v_conversation_id, v_request.requester_id)
      on conflict do nothing;
  end if;

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_request.requester_id,
    'community_join_request_accepted',
    'Join request accepted',
    'Your request to join "' || v_community.name || '" was accepted.',
    jsonb_build_object('community_id', v_community.id, 'community_name', v_community.name)
  );
end;
$$;

create or replace function cancel_community_join_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  update community_join_requests
  set status = 'cancelled'
  where id = p_request_id and requester_id = auth.uid() and status = 'pending';
end;
$$;

create or replace function leave_community(p_community_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_community communities%rowtype;
  v_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_community from communities where id = p_community_id for update;
  if v_community is null then
    raise exception 'community not found';
  end if;
  if v_community.owner_id = auth.uid() then
    raise exception 'the community owner cannot leave — delete or transfer the community instead';
  end if;
  if not exists (select 1 from community_members where community_id = p_community_id and profile_id = auth.uid()) then
    raise exception 'you are not a member of this community';
  end if;

  delete from community_members where community_id = p_community_id and profile_id = auth.uid();

  v_conversation_id := community_conversation_id(p_community_id);
  if v_conversation_id is not null then
    delete from conversation_members where conversation_id = v_conversation_id and profile_id = auth.uid();
  end if;
end;
$$;

create or replace function remove_community_member(p_community_id uuid, p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_community communities%rowtype;
  v_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_community from communities where id = p_community_id for update;
  if v_community is null then
    raise exception 'community not found';
  end if;
  if v_community.owner_id <> auth.uid() then
    raise exception 'only the community owner can remove members';
  end if;
  if p_profile_id = v_community.owner_id then
    raise exception 'the community owner cannot be removed';
  end if;
  if not exists (select 1 from community_members where community_id = p_community_id and profile_id = p_profile_id) then
    raise exception 'this person is not a member of this community';
  end if;

  delete from community_members where community_id = p_community_id and profile_id = p_profile_id;

  v_conversation_id := community_conversation_id(p_community_id);
  if v_conversation_id is not null then
    delete from conversation_members where conversation_id = v_conversation_id and profile_id = p_profile_id;
  end if;

  insert into notifications (profile_id, type, title, body, data)
  values (
    p_profile_id,
    'community_member_removed',
    'Removed from community',
    'You were removed from "' || v_community.name || '".',
    jsonb_build_object('community_id', v_community.id, 'community_name', v_community.name)
  );
end;
$$;

create or replace function set_community_member_role(p_community_id uuid, p_profile_id uuid, p_role community_role)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_community communities%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_community from communities where id = p_community_id;
  if v_community is null then
    raise exception 'community not found';
  end if;
  if v_community.owner_id <> auth.uid() then
    raise exception 'only the community owner can change member roles';
  end if;
  if p_profile_id = v_community.owner_id then
    raise exception 'the community owner''s role cannot be changed';
  end if;
  if p_role = 'admin' then
    raise exception 'only one admin (the owner) per community';
  end if;

  update community_members set role = p_role where community_id = p_community_id and profile_id = p_profile_id;

  insert into notifications (profile_id, type, title, body, data)
  values (
    p_profile_id,
    'community_role_changed',
    'Your role changed',
    'You are now ' || (case when p_role = 'moderator' then 'a moderator' else 'a member' end) || ' of "' || v_community.name || '".',
    jsonb_build_object('community_id', v_community.id, 'community_name', v_community.name, 'role', p_role)
  );
end;
$$;

alter publication supabase_realtime add table community_questions;
alter publication supabase_realtime add table community_answers;
