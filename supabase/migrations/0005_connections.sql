-- 0005_connections.sql
-- Professional connections + blocks.

create table connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(id) on delete cascade,
  receiver_id uuid not null references profiles(id) on delete cascade,
  status connection_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint connections_no_self check (requester_id <> receiver_id)
);

-- Prevent duplicate active (pending/accepted) connection requests in either direction.
create unique index connections_unique_pair_active
  on connections (least(requester_id, receiver_id), greatest(requester_id, receiver_id))
  where status in ('pending', 'accepted');

create index connections_requester_idx on connections(requester_id);
create index connections_receiver_idx on connections(receiver_id);

create table blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint blocks_no_self check (blocker_id <> blocked_id),
  constraint blocks_unique unique (blocker_id, blocked_id)
);

create index blocks_blocker_idx on blocks(blocker_id);
create index blocks_blocked_idx on blocks(blocked_id);

create or replace function is_blocked(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;
