-- 0031_posts.sql
-- Tech & Developer Posts: a global feed, distinct from `community_posts`
-- (which is scoped to a single community). Mirrors community_posts'
-- soft-delete-via-deleted_at pattern (0013) and the mention-notification
-- trigger pattern already used for meetups (0012) and team chat (0028).
--
-- `media_type` and `category` are deliberately plain `text` (+ check
-- constraints where it matters), not new Postgres enum types — this
-- migration has no need to touch the ALTER TYPE / same-transaction-usage
-- pitfall that bit conversation_type (0027) and report_target_type (0030)
-- earlier, and text keeps the client-side category chip list free to
-- change without another migration.

-- ============================================================================
-- Schema
-- ============================================================================

create table posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  content text,
  category text,
  -- Denormalized counters, unused by any query yet — reserved so a future
  -- like/comment feature (post_likes/post_comments tables) can slot in
  -- without a posts schema change. Spec: "structure the database ... so
  -- these can be added cleanly later" (Like/Comment aren't built now).
  like_count integer not null default 0,
  comment_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index posts_created_at_idx on posts(created_at desc) where deleted_at is null;
create index posts_author_idx on posts(author_id);

create table post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  media_type text not null check (media_type in ('image', 'video')),
  storage_path text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index post_media_post_idx on post_media(post_id);

create table post_links (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  url text not null,
  domain text,
  created_at timestamptz not null default now()
);

create index post_links_post_idx on post_links(post_id);

create table post_mentions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  mentioned_profile_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint post_mentions_unique unique (post_id, mentioned_profile_id)
);

create index post_mentions_post_idx on post_mentions(post_id);
create index post_mentions_profile_idx on post_mentions(mentioned_profile_id);

create trigger set_updated_at before update on posts
  for each row execute function handle_updated_at();

-- ============================================================================
-- RLS
-- ============================================================================

alter table posts enable row level security;
alter table post_media enable row level security;
alter table post_links enable row level security;
alter table post_mentions enable row level security;

create policy posts_select on posts for select
  using (deleted_at is null or author_id = auth.uid());
create policy posts_insert on posts for insert
  with check (author_id = auth.uid());
-- No client insert for like_count/comment_count drift: update is allowed
-- broadly for the author (content edits, soft-delete via deleted_at); those
-- two columns simply have no write path yet since nothing increments them.
create policy posts_update on posts for update
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

create policy post_media_select on post_media for select
  using (exists (
    select 1 from posts p where p.id = post_id and (p.deleted_at is null or p.author_id = auth.uid())
  ));
create policy post_media_write on post_media for all
  using (exists (select 1 from posts p where p.id = post_id and p.author_id = auth.uid()))
  with check (exists (select 1 from posts p where p.id = post_id and p.author_id = auth.uid()));

create policy post_links_select on post_links for select
  using (exists (
    select 1 from posts p where p.id = post_id and (p.deleted_at is null or p.author_id = auth.uid())
  ));
create policy post_links_write on post_links for all
  using (exists (select 1 from posts p where p.id = post_id and p.author_id = auth.uid()))
  with check (exists (select 1 from posts p where p.id = post_id and p.author_id = auth.uid()));

create policy post_mentions_select on post_mentions for select
  using (
    exists (select 1 from posts p where p.id = post_id and (p.deleted_at is null or p.author_id = auth.uid()))
    or mentioned_profile_id = auth.uid()
  );
create policy post_mentions_insert on post_mentions for insert
  with check (exists (select 1 from posts p where p.id = post_id and p.author_id = auth.uid()));
-- No client update/delete on post_mentions: a post's tag list is fixed at
-- creation time in this version (no edit-mentions flow yet); removing a
-- mention only ever happens as a side effect of the whole post being
-- deleted, which cascades.

-- ============================================================================
-- Mention notifications
-- ============================================================================

create or replace function notify_post_mention()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
  v_author_name text;
begin
  select author_id into v_author_id from posts where id = new.post_id;
  if v_author_id is null or v_author_id = new.mentioned_profile_id then
    return new;
  end if;

  select full_name into v_author_name from profiles where id = v_author_id;

  insert into notifications (profile_id, type, title, body, data)
  values (
    new.mentioned_profile_id,
    'post_mention',
    'You were mentioned in a post',
    coalesce(v_author_name, 'Someone') || ' mentioned you in a post.',
    jsonb_build_object('post_id', new.post_id, 'author_id', v_author_id)
  );

  return new;
end;
$$;

create trigger post_mentions_notify after insert on post_mentions
  for each row execute function notify_post_mention();

-- ============================================================================
-- Storage: post-media bucket, same owner-prefixed-path convention as
-- avatars/project-images (path: "<authorId>/<file>").
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('post-media', 'post-media', true)
on conflict (id) do nothing;

create policy "post_media_public_read" on storage.objects for select
  using (bucket_id = 'post-media');
create policy "post_media_owner_write" on storage.objects for insert
  with check (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "post_media_owner_delete" on storage.objects for delete
  using (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);
