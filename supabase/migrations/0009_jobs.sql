-- 0009_jobs.sql

create table jobs (
  id uuid primary key default gen_random_uuid(),
  poster_id uuid not null references profiles(id) on delete cascade,
  company_name text not null,
  title text not null,
  description text,
  employment_type job_employment_type not null default 'full_time',
  work_mode work_mode not null default 'remote',
  location text,
  experience_min_months integer check (experience_min_months is null or experience_min_months >= 0),
  experience_max_months integer,
  salary_min numeric(12,2) check (salary_min is null or salary_min >= 0),
  salary_max numeric(12,2),
  currency text default 'USD',
  application_url text,
  deadline timestamptz,
  status job_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint jobs_experience_range check (
    experience_max_months is null or experience_min_months is null or experience_max_months >= experience_min_months
  ),
  constraint jobs_salary_range check (
    salary_max is null or salary_min is null or salary_max >= salary_min
  )
);

create index jobs_status_deadline_idx on jobs(status, deadline);
create index jobs_poster_idx on jobs(poster_id);

create table job_required_skills (
  job_id uuid not null references jobs(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete cascade,
  primary key (job_id, skill_id)
);

create table job_applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  status job_application_status not null default 'submitted',
  cover_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_applications_unique unique (job_id, profile_id)
);

create index job_applications_job_idx on job_applications(job_id);
create index job_applications_profile_idx on job_applications(profile_id);
