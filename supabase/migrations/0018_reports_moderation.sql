-- 0018_reports_moderation.sql

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete cascade,
  target_type report_target_type not null,
  target_id uuid not null,
  category report_category not null,
  details text,
  status report_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index reports_target_idx on reports(target_type, target_id);
create index reports_status_idx on reports(status);

comment on column reports.reporter_id is 'Never exposed to the reported user; visible only to reporter and moderators.';

create table moderation_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references reports(id) on delete set null,
  moderator_id uuid not null references profiles(id) on delete cascade,
  target_type report_target_type not null,
  target_id uuid not null,
  action text not null,
  notes text,
  created_at timestamptz not null default now()
);

create index moderation_actions_target_idx on moderation_actions(target_type, target_id);
