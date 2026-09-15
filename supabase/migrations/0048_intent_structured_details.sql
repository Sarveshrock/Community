-- 0048_intent_structured_details.sql
-- The Intent form collected nearly-identical generic fields regardless of
-- what the user was actually trying to accomplish. This adds:
--   1. A single `metadata jsonb` column holding intent-type-specific data
--      (spec's own suggested approach — 19 intent types each need a
--      different handful of fields; dozens of nullable columns would be
--      unwieldy, and a dedicated table per type would fragment reads/RLS
--      for no real benefit over one flexible, indexed jsonb column).
--   2. A `fulfilled` status value, so a user can mark an intent achieved
--      without deleting their history.
--   3. A real bug fix: intents_select/intent_skills_select never actually
--      checked connections for 'connections_only' visibility — such an
--      intent was invisible to *everyone* but its owner, not just to
--      non-connections. Fixed with is_connected(), already defined in
--      0042_events_rich_details.sql for the same purpose on events.
--
-- Every change is additive/backward compatible — an intent row with no
-- metadata (every existing row) simply renders with no intent-specific
-- section, exactly as it does today. See intent_test.dart's backward-
-- compat coverage.

alter type intent_status add value if not exists 'fulfilled';

-- 'Networking' is one of this task's explicit intent categories but had no
-- enum value at all — additive, every existing value stays valid.
alter type intent_type add value if not exists 'networking';

alter table intents add column metadata jsonb not null default '{}'::jsonb;

-- Fix: connections-only intents must be visible to the owner's actual
-- connections, not just the owner.
drop policy if exists intents_select on intents;
create policy intents_select on intents for select
  using (
    profile_id = auth.uid()
    or (status = 'active' and expires_at > now() and (
      visibility = 'public'
      or (visibility = 'connections_only' and is_connected(auth.uid(), profile_id))
    ))
  );

drop policy if exists intent_skills_select on intent_skills;
create policy intent_skills_select on intent_skills for select
  using (
    exists (
      select 1 from intents i
      where i.id = intent_id
        and (
          i.profile_id = auth.uid()
          or (i.status = 'active' and i.expires_at > now() and (
            i.visibility = 'public'
            or (i.visibility = 'connections_only' and is_connected(auth.uid(), i.profile_id))
          ))
        )
    )
  );
