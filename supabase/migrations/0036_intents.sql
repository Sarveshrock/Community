-- 0036_intents.sql
-- Intent system: a user declares what they currently want to accomplish
-- (find a hackathon team, a job, a co-founder, offer mentorship, ...) so the
-- matching engine (0038) has something concrete to match candidates against,
-- instead of only ever matching against a static profile.
--
-- Expiry is deliberately NOT a stored status value: "expired" is derived as
-- status='active' and expires_at <= now(), enforced directly in the RLS
-- policy below so expired intents disappear from everyone else's view for
-- free, with no cron job needed to flip a column. The owner still sees their
-- own expired intents (to renew/delete them) via the profile_id branch.

create type intent_type as enum (
  'find_hackathon_team', 'find_hackathon_teammates', 'find_job', 'find_internship',
  'find_cofounder', 'find_developer', 'find_designer', 'find_mentor',
  'find_collaborator', 'find_project', 'find_startup_opportunity', 'find_referral',
  'find_mock_interview_partner', 'find_study_partner', 'find_open_source_contributor',
  'find_research_collaborator', 'offer_mentorship', 'offer_referral', 'offer_collaboration'
);

create type intent_visibility as enum ('public', 'connections_only');
create type intent_status as enum ('active', 'paused', 'cancelled');
create type intent_skill_direction as enum ('needed', 'offered');

create table intents (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  intent_type intent_type not null,
  title text not null,
  description text,
  experience_level experience_level not null default 'intermediate',
  preferred_role text,
  location_preference text,
  work_mode work_mode,
  commitment_level text,
  related_hackathon_id uuid references hackathons(id) on delete set null,
  related_project_id uuid references projects(id) on delete set null,
  related_job_id uuid references jobs(id) on delete set null,
  related_startup_id uuid references startups(id) on delete set null,
  visibility intent_visibility not null default 'public',
  status intent_status not null default 'active',
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint intents_related_single check (
    num_nonnulls(related_hackathon_id, related_project_id, related_job_id, related_startup_id) <= 1
  )
);

create index intents_profile_idx on intents(profile_id);
create index intents_type_idx on intents(intent_type);
create index intents_status_expires_idx on intents(status, expires_at);

alter table intents enable row level security;

create policy intents_select on intents for select
  using (
    profile_id = auth.uid()
    or (visibility = 'public' and status = 'active' and expires_at > now())
  );
create policy intents_insert on intents for insert
  with check (profile_id = auth.uid());
create policy intents_update on intents for update
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy intents_delete on intents for delete
  using (profile_id = auth.uid());

create trigger set_updated_at before update on intents
  for each row execute function handle_updated_at();

create table intent_skills (
  intent_id uuid not null references intents(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete cascade,
  direction intent_skill_direction not null,
  primary key (intent_id, skill_id, direction)
);

create index intent_skills_skill_idx on intent_skills(skill_id);

alter table intent_skills enable row level security;

create policy intent_skills_select on intent_skills for select
  using (
    exists (
      select 1 from intents i
      where i.id = intent_id
        and (i.profile_id = auth.uid() or (i.visibility = 'public' and i.status = 'active' and i.expires_at > now()))
    )
  );
create policy intent_skills_insert on intent_skills for insert
  with check (exists (select 1 from intents i where i.id = intent_id and i.profile_id = auth.uid()));
create policy intent_skills_delete on intent_skills for delete
  using (exists (select 1 from intents i where i.id = intent_id and i.profile_id = auth.uid()));
