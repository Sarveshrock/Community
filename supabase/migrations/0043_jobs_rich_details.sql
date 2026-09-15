-- 0043_jobs_rich_details.sql
-- Jobs redesign (Phase 1): "Post a Job" only ever collected title/company/
-- description/employment type/work mode/location/salary/external URL/
-- skills, so the Job Detail page looked sparse. This adds the richer
-- fields the new Job Builder and Job Detail page need — structured
-- responsibilities/requirements/benefits, fuller compensation, dynamic
-- location detail, a real internal application flow with recruiter-defined
-- custom questions, and real resume/portfolio file uploads.
--
-- Every new column is nullable/defaulted so every existing job row (and
-- every existing INSERT that only sets the original 9 fields) keeps
-- working unchanged — see event.dart's/job.dart's backward-compat tests.
--
-- Explicitly deferred (per product decision): a full employer "manage
-- applicants" dashboard beyond the existing simple list, and a dedicated
-- company/employer profile entity (company fields stay on the job row,
-- not a new company system).

-- ============================================================================
-- Enums
-- ============================================================================

-- Additive only — existing rows/values (including 'research'/'volunteer',
-- kept for whatever already used them) are untouched.
alter type job_employment_type add value if not exists 'temporary';
alter type job_employment_type add value if not exists 'other';

create type pay_period as enum ('yearly', 'monthly', 'hourly');
create type job_application_method as enum ('communeo', 'external');
create type job_question_type as enum ('short_answer', 'long_answer', 'yes_no', 'url');

-- ============================================================================
-- jobs: new columns
-- ============================================================================

alter table jobs
  add column company_logo_url text,
  add column company_website text,
  add column company_description text,
  add column job_category text,
  add column responsibilities text[] not null default '{}',
  add column experience_level experience_level,
  add column education text,
  add column prerequisites text,
  add column pay_period pay_period,
  add column salary_visible boolean not null default true,
  add column salary_negotiable boolean not null default false,
  add column bonus_info text,
  add column equity_info text,
  add column benefits text[] not null default '{}',
  add column city text,
  add column state text,
  add column country text,
  add column expected_office_days text,
  add column internship_duration_months integer check (internship_duration_months is null or internship_duration_months > 0),
  add column stipend numeric(12, 2) check (stipend is null or stipend >= 0),
  add column potential_conversion boolean not null default false,
  add column notice_period_days integer check (notice_period_days is null or notice_period_days >= 0),
  -- Every existing row only ever had `application_url` — 'external' is the
  -- correct backward-compatible default for jobs posted before this column
  -- existed.
  add column application_method job_application_method not null default 'external',
  add column application_instructions text,
  add column resume_required boolean not null default false,
  add column portfolio_required boolean not null default false,
  add column cover_letter_required boolean not null default false,
  add column contact_info text;

create index jobs_category_idx on jobs(job_category);

-- ============================================================================
-- job_preferred_skills — "nice to have", parallel to the existing
-- job_required_skills (identical shape/RLS pattern).
-- ============================================================================

create table job_preferred_skills (
  job_id uuid not null references jobs(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete cascade,
  primary key (job_id, skill_id)
);

alter table job_preferred_skills enable row level security;
create policy job_preferred_skills_select on job_preferred_skills for select using (true);
create policy job_preferred_skills_write on job_preferred_skills for all
  using (exists (select 1 from jobs j where j.id = job_id and j.poster_id = auth.uid()))
  with check (exists (select 1 from jobs j where j.id = job_id and j.poster_id = auth.uid()));

-- ============================================================================
-- job_application_questions — recruiter-defined custom questions, shown
-- during the internal application flow.
-- ============================================================================

create table job_application_questions (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  question_text text not null,
  question_type job_question_type not null default 'short_answer',
  is_required boolean not null default false,
  sort_order integer not null default 0
);

create index job_application_questions_job_idx on job_application_questions(job_id, sort_order);

alter table job_application_questions enable row level security;
create policy job_application_questions_select on job_application_questions for select using (true);
create policy job_application_questions_write on job_application_questions for all
  using (exists (select 1 from jobs j where j.id = job_id and j.poster_id = auth.uid()))
  with check (exists (select 1 from jobs j where j.id = job_id and j.poster_id = auth.uid()));

-- ============================================================================
-- job_application_answers — one applicant's answers to those questions.
-- Same privacy boundary as job_applications itself: only the applicant and
-- the job's poster can ever read an answer.
-- ============================================================================

create table job_application_answers (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references job_applications(id) on delete cascade,
  question_id uuid not null references job_application_questions(id) on delete cascade,
  answer_text text,
  constraint job_application_answers_unique unique (application_id, question_id)
);

create index job_application_answers_application_idx on job_application_answers(application_id);

alter table job_application_answers enable row level security;

create policy job_application_answers_select on job_application_answers for select
  using (
    exists (
      select 1 from job_applications a
      join jobs j on j.id = a.job_id
      where a.id = application_id
        and (a.profile_id = auth.uid() or j.poster_id = auth.uid())
    )
  );
create policy job_application_answers_insert on job_application_answers for insert
  with check (
    exists (select 1 from job_applications a where a.id = application_id and a.profile_id = auth.uid())
  );
-- No update/delete: an application's answers are submitted once, same as
-- the application itself never being edited after submission today.

-- ============================================================================
-- job_applications: new columns for the richer internal application flow.
-- resume_path/portfolio_path are raw storage paths (private bucket, see
-- below) — never a public URL, so nothing here bypasses "do not expose
-- private applicant information".
-- ============================================================================

alter table job_applications
  add column resume_path text,
  add column portfolio_path text,
  add column github_url text,
  add column linkedin_url text;

-- ============================================================================
-- Storage: a private `resumes` bucket. Path convention
-- `<profile_id>/<job_id>/<filename>` — lets the SELECT policy authorize
-- both the uploader and that specific job's poster without needing the
-- job_applications row to exist yet at upload time (mirrors
-- chat-attachments' precedent of encoding authorization into the path
-- itself, from 0039_storage_buckets.sql).
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('resumes', 'resumes', false)
on conflict (id) do nothing;

drop policy if exists "resumes_owner_write" on storage.objects;
create policy "resumes_owner_write" on storage.objects for insert
  with check (bucket_id = 'resumes' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "resumes_owner_update" on storage.objects;
create policy "resumes_owner_update" on storage.objects for update
  using (bucket_id = 'resumes' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "resumes_owner_delete" on storage.objects;
create policy "resumes_owner_delete" on storage.objects for delete
  using (bucket_id = 'resumes' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "resumes_select" on storage.objects;
create policy "resumes_select" on storage.objects for select
  using (
    bucket_id = 'resumes'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from jobs j
        where j.id::text = (storage.foldername(name))[2]
          and j.poster_id = auth.uid()
      )
    )
  );
