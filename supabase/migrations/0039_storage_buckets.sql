-- 0039_storage_buckets.sql
-- BUG FIX: `avatars`, `project-images`, `startup-logos`, `chat-attachments`,
-- and `community-media` buckets (plus their RLS policies) previously
-- existed only in seed.sql. seed.sql only ever runs automatically as part
-- of `supabase db reset` (local dev) — a real/linked project provisioned
-- via `supabase db push` never got these buckets created at all, so avatar
-- uploads either failed outright or landed nowhere any client could read
-- back, which is exactly "photo not visible after uploading, for the
-- uploader and everyone else." `post-media` (0031_posts.sql) already got
-- this right; this migration brings the rest in line with that pattern so
-- `db push` actually provisions them.
--
-- Content is copied verbatim from seed.sql's existing (already
-- drop-then-create, idempotent) versions — safe to apply on top of an
-- environment where seed.sql already created these by hand.

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('project-images', 'project-images', true),
  ('startup-logos', 'startup-logos', true),
  ('chat-attachments', 'chat-attachments', false),
  ('community-media', 'community-media', true)
on conflict (id) do nothing;

-- avatars: any authenticated user may upload to their own folder (avatars/<uid>/...)
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects for select
  using (bucket_id = 'avatars');
drop policy if exists "avatars_owner_write" on storage.objects;
create policy "avatars_owner_write" on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars_owner_update" on storage.objects;
create policy "avatars_owner_update" on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars_owner_delete" on storage.objects;
create policy "avatars_owner_delete" on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "project_images_public_read" on storage.objects;
create policy "project_images_public_read" on storage.objects for select
  using (bucket_id = 'project-images');
drop policy if exists "project_images_owner_write" on storage.objects;
create policy "project_images_owner_write" on storage.objects for insert
  with check (bucket_id = 'project-images' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "startup_logos_public_read" on storage.objects;
create policy "startup_logos_public_read" on storage.objects for select
  using (bucket_id = 'startup-logos');
drop policy if exists "startup_logos_owner_write" on storage.objects;
create policy "startup_logos_owner_write" on storage.objects for insert
  with check (bucket_id = 'startup-logos' and (storage.foldername(name))[1] = auth.uid()::text);

-- chat-attachments: private, only conversation members may read/write their own uploads
drop policy if exists "chat_attachments_member_read" on storage.objects;
create policy "chat_attachments_member_read" on storage.objects for select
  using (
    bucket_id = 'chat-attachments'
    and is_conversation_member((storage.foldername(name))[1]::uuid, auth.uid())
  );
drop policy if exists "chat_attachments_member_write" on storage.objects;
create policy "chat_attachments_member_write" on storage.objects for insert
  with check (
    bucket_id = 'chat-attachments'
    and is_conversation_member((storage.foldername(name))[1]::uuid, auth.uid())
  );

drop policy if exists "community_media_public_read" on storage.objects;
create policy "community_media_public_read" on storage.objects for select
  using (bucket_id = 'community-media');
drop policy if exists "community_media_member_write" on storage.objects;
create policy "community_media_member_write" on storage.objects for insert
  with check (bucket_id = 'community-media' and auth.uid() is not null);
