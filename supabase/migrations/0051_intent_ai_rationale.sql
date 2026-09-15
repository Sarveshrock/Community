-- 0051_intent_ai_rationale.sql
--
-- Wires Intent matching into the AI-provider layer that already exists in
-- supabase/functions/_shared/aiProvider.ts and is already live for
-- ai-match-job/ai-match-mentor/ai-match-team/ai-match-project/ai-match-startup
-- — ai-match-intent was the one match function that never called it.
--
-- Two purely additive columns on the existing intent_matches table
-- (0038_intent_matches.sql):
--   - ai_rationale: one LLM-generated, natural-language sentence explaining
--     *why* this candidate matched, in addition to the existing structured
--     `reasons text[]` (kept as-is — ai_rationale is a richer restatement of
--     the same underlying signals, not a replacement).
--   - score_breakdown: the individual weighted components (skills/interests/
--     experience/availability, each 0-1) that ai-match-intent already
--     computes internally but previously discarded after blending into the
--     single `score` — surfaced so the UI can render a compatibility
--     breakdown instead of just one percentage.
--
-- Both are nullable/defaulted, so every pre-existing intent_matches row
-- (and any row inserted before an AI provider key is configured — the
-- NoopProvider path) keeps working with ai_rationale = null and an empty
-- score_breakdown, exactly like today.

alter table intent_matches
  add column ai_rationale text,
  add column score_breakdown jsonb not null default '{}'::jsonb;

comment on column intent_matches.ai_rationale is
  'LLM-generated one-sentence match explanation. Null when no AI provider is configured (NoopProvider) or the call failed — the deterministic reasons[] array always still applies.';
comment on column intent_matches.score_breakdown is
  'Individual weighted score components (skills/interests/experience/availability, each 0-1) behind the blended `score`, for a compatibility-breakdown UI.';
