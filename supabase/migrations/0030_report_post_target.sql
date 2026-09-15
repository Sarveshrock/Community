-- 0030_report_post_target.sql
-- Adds the 'post' report_target_type value used by 0031's Posts feature
-- (so "Report inappropriate post" reuses the existing reports/moderation
-- system instead of a parallel one). Split into its own migration/transaction
-- — Postgres won't let a new enum value be used (e.g. in an insert) in the
-- same transaction that added it, and `supabase db push` can batch pending
-- migration files into one transaction (bit us earlier this session with
-- conversation_type).

alter type report_target_type add value if not exists 'post';
