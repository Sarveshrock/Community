-- 0021_analytics.sql
-- Privacy-conscious product analytics (spec section 75). Events carry only
-- the minimal ids needed to understand the action — never message content,
-- exact location, or other unnecessary personal data.

create table analytics_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) on delete set null,
  event_type text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index analytics_events_profile_idx on analytics_events(profile_id, created_at desc);
create index analytics_events_type_idx on analytics_events(event_type, created_at desc);

alter table analytics_events enable row level security;

-- Users may only log events as themselves; no client read access — analytics
-- is write-only from the app, readable only by admins/moderators (spec
-- section 73's server-side-only authorization, via the is_admin() helper
-- defined in 0019_rls.sql).
create policy analytics_events_insert on analytics_events for insert
  with check (profile_id = auth.uid());

create policy analytics_events_select_admin on analytics_events for select
  using (is_admin(auth.uid()));
