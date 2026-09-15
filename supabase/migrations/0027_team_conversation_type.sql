-- 0027_team_conversation_type.sql
-- 0028's team group chat needs a second `conversations.conversation_type`
-- value ('team'). The column was a native Postgres enum with only 'direct'
-- defined (0002/0006) — `ALTER TYPE ... ADD VALUE` cannot be *used* in the
-- same transaction that adds it, and `supabase db push` applies a batch of
-- pending migration files as one transaction, so splitting the ADD VALUE
-- into its own file (as this migration originally did) doesn't actually
-- avoid the problem when both files are pushed together. Converting the
-- column to `text` with a check constraint sidesteps it entirely: no
-- catalog value needs to be committed before it can be used, so 0028 can
-- freely insert 'team' rows in the same push. Postgrest/supabase_flutter
-- read this column as a plain string either way, so nothing downstream
-- (existing 'direct' conversation code included) changes behavior.

alter table conversations alter column conversation_type drop default;
alter table conversations alter column conversation_type type text using conversation_type::text;
alter table conversations alter column conversation_type set default 'direct';
alter table conversations add constraint conversations_conversation_type_check
  check (conversation_type in ('direct', 'team'));
