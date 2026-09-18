-- 0053_message_push_notifications.sql
-- Chat messages (1-to-1, team, and community — they all share this same
-- `messages` table, spec: "reuse existing chat infrastructure") never
-- generated a notification at all before this, in-app or push — unlike
-- every other notification type (team invitations, referrals, ...), which
-- insert directly into `notifications` from a trigger/RPC (see e.g.
-- request_to_join_team in 0026). A message can't take that shortcut: only
-- `send-notification` (the Edge Function) actually delivers to the phone's
-- notification bar via FCM, so this trigger calls it over `net.http_post`
-- instead of inserting the row itself — the same pattern already used by
-- the `refresh-tech-news` cron job in 0025_tech_intelligence_pipeline.sql.
-- `send-notification` still does the actual `notifications` insert once
-- called (and already had a `message` -> `messages` preference mapping
-- waiting, unused, since 0016/the function's own original version), so the
-- in-app Notifications screen and the system tray both end up covered by
-- this one trigger.
--
-- Like that cron job, this reads its target URL/key from placeholders you
-- must replace with your project's real values (see README) — neither is
-- secret, both already ship in the app's own .env. The x-service-secret
-- value is read from Vault by name, same as the cron job, so it's never
-- committed here: set it once, directly against the project, via
--   select vault.create_secret('<your SERVICE_FUNCTION_SECRET value>', 'service_function_secret');
-- (skip this if you already ran it for the news cron job — same secret).

create or replace function notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_name text;
  v_title text;
  v_body text;
  v_conversation_type text;
  v_team_requirement_id uuid;
  v_community_id uuid;
  v_context_name text;
  v_member record;
begin
  -- System messages ("X joined the team", etc.) aren't a person messaging
  -- you — nothing to notify about.
  if new.message_type = 'system' then
    return new;
  end if;

  select full_name into v_sender_name from profiles where id = new.sender_id;
  v_sender_name := coalesce(v_sender_name, 'Someone');

  v_body := case new.message_type
    when 'image' then 'Sent a photo'
    when 'file' then 'Sent a file'
    else left(coalesce(new.content, ''), 160)
  end;

  select c.conversation_type, c.team_requirement_id, c.community_id,
         coalesce(t.team_name, co.name)
    into v_conversation_type, v_team_requirement_id, v_community_id, v_context_name
  from conversations c
  left join hackathon_team_requirements t on t.id = c.team_requirement_id
  left join communities co on co.id = c.community_id
  where c.id = new.conversation_id;

  v_title := case
    when v_conversation_type = 'direct' then v_sender_name
    else v_sender_name || ' · ' || coalesce(v_context_name, 'Group chat')
  end;

  for v_member in
    select profile_id from conversation_members
    where conversation_id = new.conversation_id and profile_id <> new.sender_id
  loop
    perform net.http_post(
      url := 'https://rkxzoeeizkuylcmivheo.supabase.co/functions/v1/send-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer sb_publishable_R1FA5L_AHq6HRKPh0T4Y_g_wS018-mF',
        'x-service-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'service_function_secret')
      ),
      body := jsonb_build_object(
        'profile_id', v_member.profile_id,
        'type', 'message',
        'title', v_title,
        'body', v_body,
        'data', jsonb_build_object(
          'conversation_id', new.conversation_id,
          'conversation_type', v_conversation_type,
          'team_requirement_id', v_team_requirement_id,
          'community_id', v_community_id,
          'sender_id', new.sender_id
        )
      )
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists notify_new_message_trigger on messages;
create trigger notify_new_message_trigger
  after insert on messages
  for each row execute function notify_new_message();
