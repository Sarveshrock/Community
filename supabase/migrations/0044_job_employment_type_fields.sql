-- 0044_job_employment_type_fields.sql
-- Job Creation's Employment Type dropdown showed the exact same fields for
-- every type. This adds the small set of genuinely new fields needed to
-- make Freelance/Contract/Part-time/Research/Volunteer/Temporary feel
-- distinct, after maximizing reuse of existing columns (education, salary,
-- benefits, stipend, contact_info, responsibilities are all relabeled per
-- type in the app rather than duplicated here).
--
-- All columns nullable/defaulted — existing job rows keep working
-- unchanged. See job.dart's backward-compat test.

alter type pay_period add value if not exists 'fixed';

alter table jobs
  -- Freelance/Contract/Part-time/Research/Volunteer/Temporary "duration"
  -- (e.g. "3 months", "6 weeks", "ongoing") — free text since not every
  -- type's duration is a clean month count the way internship's is.
  add column engagement_duration text,
  -- Freelance "Expected hours", Contract "Expected working hours",
  -- Part-time "Hours per week", Volunteer "Time commitment".
  add column hours_per_week integer check (hours_per_week is null or hours_per_week >= 0),
  -- Part-time "Working schedule" (e.g. "Mon-Fri mornings").
  add column work_schedule text,
  -- Contract/Temporary start & end dates.
  add column contract_start_date date,
  add column contract_end_date date,
  -- Contract "Renewal possibility".
  add column renewable boolean not null default false;
