-- 0006_messaging.sql
-- 1-to-1 direct messaging (MVP scope: direct only).

create table conversations (
  id uuid primary key default gen_random_uuid(),
  conversation_type conversation_type not null default 'direct',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table conversation_members (
  conversation_id uuid not null references conversations(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  primary key (conversation_id, profile_id)
);

create index conversation_members_profile_idx on conversation_members(profile_id);

create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  message_type message_type not null default 'text',
  content text,
  attachment_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint messages_content_required check (
    (message_type = 'text' and content is not null)
    or (message_type in ('image', 'file') and attachment_url is not null)
    or (message_type = 'system')
  )
);

create index messages_conversation_created_idx on messages(conversation_id, created_at);
create index messages_sender_idx on messages(sender_id);

create table message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references messages(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  constraint message_reactions_unique unique (message_id, profile_id, emoji)
);

-- Helper: does a direct conversation already exist between two profiles?
create or replace function find_direct_conversation(user_a uuid, user_b uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select cm1.conversation_id
  from conversation_members cm1
  join conversation_members cm2
    on cm1.conversation_id = cm2.conversation_id and cm2.profile_id = user_b
  join conversations c on c.id = cm1.conversation_id
  where cm1.profile_id = user_a
    and c.conversation_type = 'direct'
  limit 1;
$$;

-- Creates (or returns existing) direct conversation between the caller and
-- another profile, enforcing block checks server-side.
create or replace function get_or_create_direct_conversation(other_profile_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := auth.uid();
  existing uuid;
  new_conversation_id uuid;
begin
  if caller is null then
    raise exception 'not authenticated';
  end if;
  if caller = other_profile_id then
    raise exception 'cannot message yourself';
  end if;
  if is_blocked(caller, other_profile_id) then
    raise exception 'messaging blocked between these users';
  end if;

  existing := find_direct_conversation(caller, other_profile_id);
  if existing is not null then
    return existing;
  end if;

  insert into conversations (conversation_type) values ('direct')
  returning id into new_conversation_id;

  insert into conversation_members (conversation_id, profile_id)
  values (new_conversation_id, caller), (new_conversation_id, other_profile_id);

  return new_conversation_id;
end;
$$;
