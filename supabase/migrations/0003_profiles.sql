-- 0003_profiles.sql
-- Core profile table plus experience/education/roles.

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  full_name text,
  avatar_url text,
  bio text,
  city text,
  country text,
  -- Privacy-safe approximate location only. Never store/query exact GPS.
  approx_latitude numeric(6,2),
  approx_longitude numeric(6,2),
  primary_user_type user_type not null default 'other',
  current_company text,
  -- "current_role" is a reserved word in Postgres (same family as
  -- current_user/current_date) — must stay quoted in any raw SQL that
  -- references it (PostgREST/supabase-js calls from Dart already quote
  -- column names automatically, so this only matters in .sql files).
  "current_role" text,
  total_it_experience_months integer not null default 0 check (total_it_experience_months >= 0),
  is_open_to_work boolean not null default false,
  is_open_to_internship boolean not null default false,
  is_open_to_freelance boolean not null default false,
  is_open_to_mentorship boolean not null default false,
  professional_discoverable boolean not null default true,
  local_discoverable boolean not null default false,
  profile_completed boolean not null default false,
  college text,
  degree text,
  field_of_study text,
  graduation_year integer,
  career_goals text,
  availability text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_format check (username is null or username ~ '^[a-z0-9_]{3,30}$')
);

comment on table profiles is 'Primary professional profile, 1:1 with auth.users';
comment on column profiles.approx_latitude is 'Rounded/fuzzed coordinate, privacy-safe only. Never exact.';

create table user_roles (
  profile_id uuid not null references profiles(id) on delete cascade,
  role app_role not null default 'user',
  granted_at timestamptz not null default now(),
  primary key (profile_id, role)
);

comment on table user_roles is 'Server-authorized elevated roles. Never trust client-supplied role claims.';

create table experiences (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  company_name text not null,
  role text not null,
  employment_type employment_type not null default 'full_time',
  start_date date not null,
  end_date date,
  is_current boolean not null default false,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint experiences_date_range check (end_date is null or end_date >= start_date)
);

create table education (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  institution text not null,
  degree text,
  field_of_study text,
  start_year integer,
  end_year integer,
  is_current boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint education_year_range check (end_year is null or start_year is null or end_year >= start_year)
);
