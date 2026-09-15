-- 0049_profile_photo_privacy.sql
--
-- Adds a per-user "who can see my real profile photo" setting, enforced at
-- the Storage layer (not just in the UI) — the `avatars` bucket was created
-- `public = true` in 0039_storage_buckets.sql, and a public bucket serves
-- objects unconditionally through Supabase's public CDN endpoint regardless
-- of any `storage.objects` RLS policy, so no per-viewer restriction was ever
-- possible while it stayed public. This migration:
--
--   1. Adds `photo_visibility` to `profiles` (everyone/connections/only_me,
--      default 'everyone' — matches today's actual behavior exactly, so no
--      existing profile's photo becomes newly hidden OR newly exposed).
--   2. Adds `can_view_profile_photo(viewer, owner)` — the single rule every
--      part of the app defers to. Mirrors `is_connected()` (0042) for the
--      "connections only" branch rather than reinventing connection logic.
--   3. Flips the `avatars` bucket to private and replaces the old
--      unconditional `avatars_public_read` policy with one that calls
--      `can_view_profile_photo`, keyed off the existing `<profile_id>/...`
--      upload path convention (0039) — real enforcement, not a client-side
--      courtesy check.
--   4. Backfills existing `avatar_url` values (currently full public URLs)
--      down to the bare `<profile_id>/avatar.<ext>` path, since a private
--      bucket's objects are no longer reachable via that public URL form —
--      the app now resolves a short-lived signed URL from the path on
--      demand (see `avatarSignedUrlProvider`), the same pattern already
--      used for the private `resumes` and `chat-attachments` buckets.
--
-- Backward compatible: every existing row defaults to 'everyone' (today's
-- real behavior), every existing avatar keeps working once resolved through
-- a signed URL, and the generic-avatar sentinel (`generic-avatar://N`,
-- handled entirely client-side, never touches Storage) is untouched by the
-- backfill below since it never matches the public-URL pattern.

create type profile_photo_visibility as enum ('everyone', 'connections', 'only_me');

alter table profiles
  add column photo_visibility profile_photo_visibility not null default 'everyone';

create or replace function can_view_profile_photo(p_viewer uuid, p_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_viewer is not null and p_viewer = p_owner then true
    else case (select photo_visibility from profiles where id = p_owner)
      when 'everyone' then true
      when 'connections' then p_viewer is not null and is_connected(p_viewer, p_owner)
      else false -- 'only_me', or the owner row no longer exists
    end
  end;
$$;

comment on function can_view_profile_photo(uuid, uuid) is
  'Single source of truth for profile-photo visibility. Event/community/team/group '
  'membership is deliberately never consulted here — only self, the owner''s '
  'photo_visibility setting, and (for ''connections'') an accepted mutual connection.';

-- Bare paths look like "<uuid>/avatar.ext" (no scheme); a legacy public URL
-- looks like ".../storage/v1/object/public/avatars/<uuid>/avatar.ext". Strip
-- the prefix so every row ends up path-only, matching what new uploads write.
update profiles
set avatar_url = regexp_replace(avatar_url, '^.*/storage/v1/object/public/avatars/', '')
where avatar_url like '%/storage/v1/object/public/avatars/%';

update storage.buckets set public = false where id = 'avatars';

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_read_if_authorized" on storage.objects for select
  using (
    bucket_id = 'avatars'
    and can_view_profile_photo(auth.uid(), nullif((storage.foldername(name))[1], '')::uuid)
  );
