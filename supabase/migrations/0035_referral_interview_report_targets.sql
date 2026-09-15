-- 0035_referral_interview_report_targets.sql
-- Adds 'referral_offer' and 'interview_practice_profile' report_target_type
-- values so the existing report/moderation system covers 0033/0034's new
-- entities. Split into its own migration/transaction, same reason as
-- 0030_report_post_target.sql: Postgres won't let a new enum value be used
-- in the same transaction that added it.

alter type report_target_type add value if not exists 'referral_offer';
alter type report_target_type add value if not exists 'interview_practice_profile';
