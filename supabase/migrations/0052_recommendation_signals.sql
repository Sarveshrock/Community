-- 0052_recommendation_signals.sql
--
-- "Communeo Intelligence" P0: extends Intent matching (0036/0038/0051) from
-- people-only into a cross-entity recommendation layer — communities,
-- events, projects, and posts connected to a user's current Intent via
-- their already-computed top matches. This is purely additive: nothing in
-- 0036/0038/0051 changes, and every new table/function follows the exact
-- RLS/ownership patterns already established for intent_matches, is_connected,
-- and is_community_member.
--
-- New pieces:
--   1. `accepted_connection_ids(p)` / `mutual_connection_count(a,b)` — RLS on
--      `connections` (0019_rls.sql) only lets a user see rows they're a
--      party to, which makes "connections in common" impossible to compute
--      client-side. Two small SECURITY DEFINER functions, mirroring
--      is_connected()'s existing pattern, are the standard, minimal way to
--      expose just the *count*/*id set* without exposing anyone's raw
--      connections rows.
--   2. `intent_recommendations` — the cross-entity counterpart to
--      intent_matches (0038), same select-by-owner RLS shape, denormalizing
--      display fields (title/subtitle/image) exactly like intent_matches
--      denormalizes full_name/avatar_url so the client never needs an extra
--      per-row join.

create type intent_recommendation_type as enum ('community', 'event', 'project', 'post');

create table intent_recommendations (
  id uuid primary key default gen_random_uuid(),
  intent_id uuid not null references intents(id) on delete cascade,
  recommendation_type intent_recommendation_type not null,
  target_id uuid not null,
  title text not null,
  subtitle text,
  image_url text,
  score numeric(5,2) not null check (score >= 0 and score <= 100),
  reasons text[] not null default '{}',
  ai_rationale text,
  signal_breakdown jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint intent_recommendations_unique unique (intent_id, recommendation_type, target_id)
);

create index intent_recommendations_intent_score_idx
  on intent_recommendations(intent_id, score desc);

alter table intent_recommendations enable row level security;

create policy intent_recommendations_select on intent_recommendations for select
  using (auth.uid() = (select profile_id from intents where id = intent_id));

comment on table intent_recommendations is
  'Cross-entity ("community"/"event"/"project"/"post") recommendations tied to an Intent — the counterpart to intent_matches (people-only). Populated by the get-network-recommendations edge function, never written to directly by clients.';

-- ============================================================================
-- Connection-graph helpers
-- ============================================================================

create or replace function accepted_connection_ids(p uuid)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select case when requester_id = p then receiver_id else requester_id end
  from connections
  where status = 'accepted' and (requester_id = p or receiver_id = p);
$$;

comment on function accepted_connection_ids(uuid) is
  'All profile ids with an accepted connection to p. RLS on connections only lets a user see rows they''re a party to, so this SECURITY DEFINER wrapper is the only way to compute anything graph-shaped (e.g. connections-in-common, 2nd-degree) without exposing raw connection rows.';

create or replace function mutual_connection_count(a uuid, b uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from accepted_connection_ids(a) x
  where x in (select accepted_connection_ids(b));
$$;

comment on function mutual_connection_count(uuid, uuid) is
  'Count of accepted connections shared between a and b — used as one input to the recommendation/"why you should meet" scoring signal, never to list the actual mutual people (that would need its own authorization check).';
