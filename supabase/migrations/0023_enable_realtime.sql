-- 0023_enable_realtime.sql
-- Realtime chat (spec section 19) subscribes to Postgres changes on
-- `messages` via supabase_flutter's `.stream()`. That requires the table to
-- be in the `supabase_realtime` publication — it isn't there by default on
-- a fresh Supabase project, which surfaces as a client-side
-- RealtimeSubscribeException("channelError ... Realtime is enabled for the
-- given connect parameters") rather than a migration error, so it's easy to
-- miss until you actually open a chat.

alter publication supabase_realtime add table messages;
