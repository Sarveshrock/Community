-- 0015_news.sql
-- Metadata/summaries only. Never store full copyrighted article bodies.

create table news_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  source_type text not null default 'article',
  base_url text,
  created_at timestamptz not null default now()
);

create table news_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table news_items (
  id uuid primary key default gen_random_uuid(),
  source_id uuid references news_sources(id) on delete set null,
  title text not null,
  summary text,
  url text not null,
  published_at timestamptz,
  image_url text,
  external_id text,
  source_author text,
  category text,
  ai_summary text,
  why_it_matters text,
  technical_impact text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index news_items_source_external_unique
  on news_items(source_id, external_id) where external_id is not null;
create index news_items_published_at_idx on news_items(published_at desc);

create table news_item_categories (
  news_item_id uuid not null references news_items(id) on delete cascade,
  category_id uuid not null references news_categories(id) on delete cascade,
  primary key (news_item_id, category_id)
);

create table saved_news (
  profile_id uuid not null references profiles(id) on delete cascade,
  news_item_id uuid not null references news_items(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (profile_id, news_item_id)
);

create table hidden_news (
  profile_id uuid not null references profiles(id) on delete cascade,
  news_item_id uuid not null references news_items(id) on delete cascade,
  hidden_at timestamptz not null default now(),
  primary key (profile_id, news_item_id)
);
