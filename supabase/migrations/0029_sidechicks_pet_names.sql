-- 0029_sidechicks_pet_names.sql
-- "Sidechicks": a personalized view of one's existing (accepted)
-- connections, adding a private per-viewer pet name. Reuses the existing
-- `connections` table entirely — no parallel connection system.
--
-- Also fixes a real pre-existing gap found while building this: `connections`
-- had select/insert/update policies (0019) but no delete policy, so the
-- already-defined `removeConnection()` repository method (never wired to any
-- UI) would have silently failed with a permission error the moment
-- "Disconnect" tried to use it.

-- ============================================================================
-- Fix: connections had no delete policy at all
-- ============================================================================

create policy connections_delete on connections for delete
  using (requester_id = auth.uid() or receiver_id = auth.uid());

-- ============================================================================
-- Pet names: private, per-owner, per-connection labels
-- ============================================================================
-- Deliberately keyed off (connection_id, owner_id) rather than living as a
-- column on `connections` itself — a column there would be one shared value
-- both parties could see, which breaks the "User A's pet name for User B is
-- invisible to User B" requirement. This way RLS alone enforces that
-- isolation: nobody can select a row where owner_id <> auth.uid().

create table connection_nicknames (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references connections(id) on delete cascade,
  owner_id uuid not null references profiles(id) on delete cascade,
  nickname text not null check (length(trim(nickname)) > 0 and length(nickname) <= 60),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- One pet name per (connection, owner): upsert-on-conflict is how the
  -- client edits/replaces it, "removable" is a plain delete.
  constraint connection_nicknames_unique unique (connection_id, owner_id)
);

create index connection_nicknames_owner_idx on connection_nicknames(owner_id);

alter table connection_nicknames enable row level security;

create policy connection_nicknames_select on connection_nicknames for select
  using (owner_id = auth.uid());

-- A single "for all" policy covers insert/update/delete: the owner must be
-- setting their own row, and must actually be one of the two parties on the
-- connection they're labeling (can't nickname a connection you're not in).
create policy connection_nicknames_write on connection_nicknames for all
  using (
    owner_id = auth.uid()
    and exists (
      select 1 from connections c
      where c.id = connection_id
        and (c.requester_id = auth.uid() or c.receiver_id = auth.uid())
    )
  )
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from connections c
      where c.id = connection_id
        and (c.requester_id = auth.uid() or c.receiver_id = auth.uid())
    )
  );

create trigger set_updated_at before update on connection_nicknames
  for each row execute function handle_updated_at();
