-- 0024_live_news_api.sql
-- News is no longer ingested into Supabase at all: the app fetches live
-- from a News API through the get-news Edge Function, and Supabase is not
-- the source of news content. Drops the now-unused ingestion schema and
-- rebuilds saved_news/hidden_news around the article's URL (its only stable
-- identity from an external API) instead of a FK to a local news_items row.

drop table if exists news_item_categories;
drop table if exists saved_news;
drop table if exists hidden_news;
drop table if exists news_items;
drop table if exists news_categories;
drop table if exists news_sources;

create table saved_news (
  profile_id uuid not null references profiles(id) on delete cascade,
  article_url text not null,
  title text not null,
  summary text,
  image_url text,
  source_name text,
  published_at timestamptz,
  category text,
  saved_at timestamptz not null default now(),
  primary key (profile_id, article_url)
);

create table hidden_news (
  profile_id uuid not null references profiles(id) on delete cascade,
  article_url text not null,
  hidden_at timestamptz not null default now(),
  primary key (profile_id, article_url)
);

alter table saved_news enable row level security;
alter table hidden_news enable row level security;

create policy saved_news_select on saved_news for select using (profile_id = auth.uid());
create policy saved_news_write on saved_news for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy hidden_news_select on hidden_news for select using (profile_id = auth.uid());
create policy hidden_news_write on hidden_news for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
