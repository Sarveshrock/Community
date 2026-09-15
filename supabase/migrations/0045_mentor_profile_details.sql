-- 0045_mentor_profile_details.sql
-- "Become a Mentor" had no UI entry point at all. Everything a mentor
-- profile needs already existed (expertise, topics, pricing, session
-- duration, availability toggle) except a handful of small descriptive
-- fields the new Create/Edit Mentor flow needs. All nullable — existing
-- mentor_profiles rows keep working unchanged.

alter table mentor_profiles
  -- Short one-line pitch, shown above the longer `bio` ("about your
  -- mentorship") on the mentor card/detail page.
  add column headline text,
  -- '1:1' | 'group' | 'both' — plain text (mirrors jobs.job_category's
  -- pattern of a Dart-list-backed text column, not a new DB enum).
  add column mentorship_type text,
  -- e.g. {'chat','video_call','voice_call','in_person'}.
  add column communication_modes text[] not null default '{}',
  -- Free-text availability description (e.g. "Mon/Wed 7-9 PM IST").
  -- Deliberately not a structured schedule/calendar system — none exists
  -- elsewhere in Communeo's mentorship feature, and building one is out
  -- of scope here.
  add column availability_note text;
