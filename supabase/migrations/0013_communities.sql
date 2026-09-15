-- 0013_communities.sql

create table communities (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  slug text not null unique,
  description text,
  cover_image_url text,
  community_type community_type not null default 'interest_based',
  is_private boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table community_members (
  community_id uuid not null references communities(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  role community_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (community_id, profile_id)
);

create table community_posts (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index community_posts_community_idx on community_posts(community_id, created_at desc);

create table community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references community_posts(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index community_comments_post_idx on community_comments(post_id, created_at);
