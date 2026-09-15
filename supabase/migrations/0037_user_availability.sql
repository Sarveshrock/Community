-- 0037_user_availability.sql
-- Optional structured availability (spec-extension section 10), used by the
-- matching engine (0038) to compute an "available at compatible times"
-- signal. RLS is owner-only in both directions on purpose: another user's
-- raw schedule is never queryable directly. Cross-user compatibility is
-- computed inside the ai-match-intent edge function using its service-role
-- client (which bypasses RLS server-side), and only a boolean ever leaves
-- that function — never another person's actual time slots.

create table user_availability (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null,
  created_at timestamptz not null default now(),
  constraint user_availability_time_range check (end_time > start_time)
);

create index user_availability_profile_idx on user_availability(profile_id);

alter table user_availability enable row level security;

create policy user_availability_select on user_availability for select
  using (profile_id = auth.uid());
create policy user_availability_insert on user_availability for insert
  with check (profile_id = auth.uid());
create policy user_availability_delete on user_availability for delete
  using (profile_id = auth.uid());
