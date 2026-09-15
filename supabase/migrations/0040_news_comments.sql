-- 0040_news_comments.sql
-- Lets users give their opinion on a news article, and reply to each
-- other's opinions with the replied-to person tagged by name.
--
-- Keyed by `article_url` (text), not a `news_items.id` FK: news_items rows
-- are pipeline-owned (0025_tech_intelligence_pipeline.sql) and get-news can
-- in principle stop returning/re-upsert an old story, but the article's URL
-- is the one identity that's stable across the app's own screens — it's
-- exactly the same reasoning 0024_live_news_api.sql already used for
-- saved_news/hidden_news, so comments follow the same precedent instead of
-- a fragile FK to a row that isn't guaranteed to still exist.
--
-- Threading is flattened one level deep (Instagram-style): every reply's
-- `parent_comment_id` always points at a top-level comment, never at
-- another reply — resolved client-side when posting a reply-to-a-reply, so
-- the UI only ever needs to render two tiers, not an arbitrary tree.
-- `mentioned_profile_id` is separate from `parent_comment_id` because who a
-- reply is *addressed to* (the tag shown as "@Name") is the specific
-- comment/reply author being replied to, which for a reply-to-a-reply is
-- not the same person as the top-level comment's author.

create table news_comments (
  id uuid primary key default gen_random_uuid(),
  article_url text not null,
  author_id uuid not null references profiles(id) on delete cascade,
  parent_comment_id uuid references news_comments(id) on delete cascade,
  mentioned_profile_id uuid references profiles(id) on delete set null,
  content text not null check (length(trim(content)) > 0 and length(content) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index news_comments_article_idx on news_comments(article_url, created_at);
create index news_comments_parent_idx on news_comments(parent_comment_id);

create trigger set_updated_at before update on news_comments
  for each row execute function handle_updated_at();

alter table news_comments enable row level security;

-- News itself is public to every signed-in user (news_items_select_all),
-- so opinions on it are public the same way — no ownership/visibility
-- check beyond "you're signed in", matching news_items' own select policy.
create policy news_comments_select on news_comments for select
  using (auth.uid() is not null);

create policy news_comments_insert on news_comments for insert
  with check (
    author_id = auth.uid()
    -- A reply must target a real top-level comment on the same article,
    -- not an arbitrary/foreign id a client could otherwise supply.
    and (
      parent_comment_id is null
      or exists (
        select 1 from news_comments p
        where p.id = parent_comment_id
          and p.article_url = article_url
          and p.parent_comment_id is null
      )
    )
  );

-- Soft-deleted via update (deleted_at), same as post_comments/community_comments.
create policy news_comments_update on news_comments for update
  using (author_id = auth.uid())
  with check (author_id = auth.uid());
