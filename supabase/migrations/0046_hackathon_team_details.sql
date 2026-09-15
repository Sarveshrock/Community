-- 0046_hackathon_team_details.sql
-- The "Find a Team" form only ever collected team name/description/a flat
-- required_roles text[]/team_size/required skills — not enough for anyone
-- to understand a team or for Communeo to match people to it. This adds
-- the structured fields the new Team Builder/Team Page/Team Card need.
--
-- Every new column is nullable/defaulted so every existing team row keeps
-- working unchanged — see hackathon_test.dart's backward-compat coverage.
-- Existing tables/columns (hackathon_team_requirements' original fields,
-- hackathon_team_members, hackathon_team_join_requests, team_invitations,
-- hackathon_team_required_skills) are reused as-is, not duplicated.

-- ============================================================================
-- Enums
-- ============================================================================

create type team_visibility as enum ('public', 'communeo_users', 'connections_only');

-- ============================================================================
-- hackathon_team_requirements: new columns
-- ============================================================================

alter table hackathon_team_requirements
  add column tagline text,
  add column project_stage text,
  add column min_team_size integer check (min_team_size is null or min_team_size >= 1),
  add column commitment text,
  add column preferred_times text,
  add column timezone text,
  add column collaboration_mode text not null default 'online',
  add column location text,
  add column communication_platform text,
  add column preferred_experience_level text,
  add column team_culture text[] not null default '{}',
  add column expectations text,
  add column github_url text,
  add column figma_url text,
  add column website_url text,
  add column demo_url text,
  add column pitch_deck_url text,
  add column visibility team_visibility not null default 'public';

-- ============================================================================
-- hackathon_team_role_requirements — the structured "Looking For" list,
-- replacing the flat required_roles text[] (kept, unused by new teams, so
-- old rows still render via it).
-- ============================================================================

create table hackathon_team_role_requirements (
  id uuid primary key default gen_random_uuid(),
  team_requirement_id uuid not null references hackathon_team_requirements(id) on delete cascade,
  role_name text not null,
  priority text,
  description text,
  experience_level text,
  sort_order integer not null default 0
);

create index hackathon_team_role_requirements_team_idx on hackathon_team_role_requirements(team_requirement_id, sort_order);

alter table hackathon_team_role_requirements enable row level security;
create policy hackathon_team_role_requirements_select on hackathon_team_role_requirements for select using (true);
create policy hackathon_team_role_requirements_write on hackathon_team_role_requirements for all
  using (exists (select 1 from hackathon_team_requirements r where r.id = team_requirement_id and r.creator_id = auth.uid()))
  with check (exists (select 1 from hackathon_team_requirements r where r.id = team_requirement_id and r.creator_id = auth.uid()));

-- Per-role skills — reuses the existing global `skills` table, same shape
-- as hackathon_team_required_skills, just scoped to one role instead of
-- the whole team.
create table hackathon_team_role_required_skills (
  role_requirement_id uuid not null references hackathon_team_role_requirements(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete cascade,
  primary key (role_requirement_id, skill_id)
);

alter table hackathon_team_role_required_skills enable row level security;
create policy hackathon_team_role_required_skills_select on hackathon_team_role_required_skills for select using (true);
create policy hackathon_team_role_required_skills_write on hackathon_team_role_required_skills for all
  using (
    exists (
      select 1 from hackathon_team_role_requirements rr
      join hackathon_team_requirements r on r.id = rr.team_requirement_id
      where rr.id = role_requirement_id and r.creator_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from hackathon_team_role_requirements rr
      join hackathon_team_requirements r on r.id = rr.team_requirement_id
      where rr.id = role_requirement_id and r.creator_id = auth.uid()
    )
  );

-- ============================================================================
-- hackathon_team_skills_have — "skills we already have", the counterpart to
-- the existing hackathon_team_required_skills ("skills we're looking for").
-- Identical shape/RLS to that table.
-- ============================================================================

create table hackathon_team_skills_have (
  team_requirement_id uuid not null references hackathon_team_requirements(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete cascade,
  primary key (team_requirement_id, skill_id)
);

alter table hackathon_team_skills_have enable row level security;
create policy hackathon_team_skills_have_select on hackathon_team_skills_have for select using (true);
create policy hackathon_team_skills_have_write on hackathon_team_skills_have for all
  using (exists (select 1 from hackathon_team_requirements r where r.id = team_requirement_id and r.creator_id = auth.uid()))
  with check (exists (select 1 from hackathon_team_requirements r where r.id = team_requirement_id and r.creator_id = auth.uid()));

-- ============================================================================
-- Visibility-aware SELECT policy (spec section 13). Reuses is_connected(),
-- already defined in 0042_events_rich_details.sql for the same purpose on
-- events — not duplicated here.
-- ============================================================================

drop policy if exists hackathon_team_requirements_select_all on hackathon_team_requirements;
create policy hackathon_team_requirements_select on hackathon_team_requirements for select
  using (
    visibility = 'public'
    or creator_id = auth.uid()
    or (visibility = 'communeo_users' and auth.uid() is not null)
    or (visibility = 'connections_only' and is_connected(auth.uid(), creator_id))
  );

-- ============================================================================
-- remove_team_member — the owner-only action the schema never had (only
-- self-leave and owner-delete existed). Mirrors leave_team's shape exactly,
-- including reopening a full team and revoking chat access.
-- ============================================================================

create or replace function remove_team_member(p_team_requirement_id uuid, p_profile_id uuid)
returns void
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

  select * into v_team from hackathon_team_requirements where id = p_team_requirement_id for update;
  if v_team is null then
    raise exception 'team not found';
  end if;
  if v_team.creator_id <> auth.uid() then
    raise exception 'only the team owner can remove members';
  end if;
  if p_profile_id = v_team.creator_id then
    raise exception 'the team owner cannot remove themself — delete the team instead';
  end if;
  if not exists (
    select 1 from hackathon_team_members where team_requirement_id = p_team_requirement_id and profile_id = p_profile_id
  ) then
    raise exception 'this person is not a member of this team';
  end if;

  delete from hackathon_team_members
    where team_requirement_id = p_team_requirement_id and profile_id = p_profile_id;

  v_conversation_id := team_conversation_id(p_team_requirement_id);
  if v_conversation_id is not null then
    delete from conversation_members
      where conversation_id = v_conversation_id and profile_id = p_profile_id;
  end if;

  if v_team.status = 'full' then
    update hackathon_team_requirements set status = 'open' where id = p_team_requirement_id;
  end if;

  insert into notifications (profile_id, type, title, body, data)
  values (
    p_profile_id,
    'team_member_removed',
    'Removed from team',
    'You were removed from "' || v_team.team_name || '".',
    jsonb_build_object('team_requirement_id', v_team.id, 'team_name', v_team.team_name, 'hackathon_id', v_team.hackathon_id)
  );
end;
$$;
