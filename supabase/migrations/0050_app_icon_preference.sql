-- 0050_app_icon_preference.sql
--
-- Remembers which launcher-icon style a user picked (Settings > Appearance >
-- App Icon) so it can be re-applied automatically the next time they sign in
-- on a device — the actual OS-level icon swap is inherently per-device (no
-- platform lets one device push a launcher icon to another), so this column
-- only stores *intent*; `AppIconController` re-applies it locally on login.
--
-- A plain text column (like `jobs.job_category`) rather than a new enum —
-- icon styles are cosmetic catalog entries the client already validates
-- against `kAppIconStyles`, so adding a future style never needs a migration.
-- Deliberately a separate column from Feature 2's `photo_visibility`: one is
-- an appearance preference, the other a privacy preference, and the two must
-- never share a data model.

alter table profiles
  add column app_icon_style text not null default 'classic';
