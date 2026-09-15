-- 0032_post_likes_comments.sql
-- Like/Comment for posts — the piece 0031 deliberately deferred (its
-- `posts.like_count`/`comment_count` columns exist for exactly this).
-- post_comments mirrors community_comments' soft-delete-via-deleted_at
-- pattern (0013); the two counter columns are kept in sync by triggers
-- rather than trusted from the client, so a client bug can't desync them.

-- ============================================================================
-- Schema
-- ============================================================================

create table post_likes (
  post_id uuid not null references posts(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, profile_id)
);

create index post_likes_post_idx on post_likes(post_id);

create table post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index post_comments_post_idx on post_comments(post_id, created_at);

create trigger set_updated_at before update on post_comments
  for each row execute function handle_updated_at();

-- ============================================================================
-- RLS
-- ============================================================================

alter table post_likes enable row level security;
alter table post_comments enable row level security;

create policy post_likes_select on post_likes for select
  using (exists (
    select 1 from posts p where p.id = post_id and (p.deleted_at is null or p.author_id = auth.uid())
  ));
create policy post_likes_insert on post_likes for insert
  with check (
    profile_id = auth.uid()
    and exists (select 1 from posts p where p.id = post_id and p.deleted_at is null)
  );
-- Unlike: the only way to remove your own like row.
create policy post_likes_delete on post_likes for delete
  using (profile_id = auth.uid());

create policy post_comments_select on post_comments for select
  using (exists (
    select 1 from posts p where p.id = post_id and (p.deleted_at is null or p.author_id = auth.uid())
  ));
create policy post_comments_insert on post_comments for insert
  with check (
    author_id = auth.uid()
    and exists (select 1 from posts p where p.id = post_id and p.deleted_at is null)
  );
-- Comments are soft-deleted via update (deleted_at), same as posts/community
-- comments — no client delete policy needed.
create policy post_comments_update on post_comments for update
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

-- ============================================================================
-- Keep posts.like_count / comment_count in sync server-side — never trust a
-- client-supplied count (posts_update's RLS would let the author set it to
-- anything otherwise).
-- ============================================================================

create or replace function sync_post_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update posts set like_count = like_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update posts set like_count = greatest(like_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$;

create trigger post_likes_sync_count
  after insert or delete on post_likes
  for each row execute function sync_post_like_count();

create or replace function sync_post_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update posts set comment_count = comment_count + 1 where id = new.post_id;
  elsif tg_op = 'UPDATE' and old.deleted_at is null and new.deleted_at is not null then
    update posts set comment_count = greatest(comment_count - 1, 0) where id = new.post_id;
  elsif tg_op = 'UPDATE' and old.deleted_at is not null and new.deleted_at is null then
    update posts set comment_count = comment_count + 1 where id = new.post_id;
  end if;
  return null;
end;
$$;

create trigger post_comments_sync_count
  after insert or update on post_comments
  for each row execute function sync_post_comment_count();
