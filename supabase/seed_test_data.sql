-- seed_test_data.sql
-- OPTIONAL, MANUAL test data for exercising Buddies/connections,
-- messaging, and hackathon teams end-to-end. NOT run automatically by
-- `supabase db push` or `db reset` (unlike seed.sql) — paste this into the
-- Supabase Dashboard's SQL Editor (or `psql`) yourself, whenever you want
-- it. Safe to re-run; every step checks for existing rows first.
--
-- This script deliberately never touches auth.users. Creating a real,
-- working Supabase Auth user needs password hashing, email-confirmation
-- state, and an auth.identities row that a plain SQL insert can't safely
-- replicate — and this runs against your live linked project, so it's not
-- somewhere to improvise. Sign up 2-3 test accounts through the app's own
-- sign-up screen first (e.g. test1@..., test2@..., test3@...) — that's the
-- same two minutes of work and guarantees logins that actually work. Then
-- run this script: it picks up your most-recently-created profiles and
-- wires realistic data between them.

do $$
declare
  v_ids uuid[];
  v_a uuid;
  v_b uuid;
  v_c uuid;
  v_hackathon_id uuid;
  v_team_id uuid;
  v_direct_conv_id uuid;
  v_team_conv_id uuid;
begin
  select array_agg(id) into v_ids
  from (select id from profiles order by created_at desc limit 3) t;

  if v_ids is null or array_length(v_ids, 1) < 2 then
    raise notice 'Need at least 2 signed-up profiles first — sign up a couple of test accounts through the app, then re-run this script.';
    return;
  end if;

  v_a := v_ids[1];
  v_b := v_ids[2];
  v_c := v_ids[3]; -- may be null if only 2 test accounts exist so far

  -- Skip onboarding for these test accounts so logging into them lands on
  -- Home instead of the onboarding flow.
  update profiles set profile_completed = true
  where id = any(v_ids) and profile_completed = false;

  -- ==========================================================================
  -- Connections + a pet name (Buddies)
  -- ==========================================================================

  if not exists (
    select 1 from connections
    where (requester_id = v_a and receiver_id = v_b) or (requester_id = v_b and receiver_id = v_a)
  ) then
    insert into connections (requester_id, receiver_id, status) values (v_a, v_b, 'accepted');
  end if;

  -- A's private pet name for B — sign in as A to see "... (Bestie)"; sign in
  -- as B and you should still see just their own main name.
  insert into connection_nicknames (connection_id, owner_id, nickname)
  select conn.id, v_a, 'Bestie'
  from connections conn
  where (conn.requester_id = v_a and conn.receiver_id = v_b) or (conn.requester_id = v_b and conn.receiver_id = v_a)
  on conflict (connection_id, owner_id) do update set nickname = excluded.nickname;

  if v_c is not null then
    if not exists (
      select 1 from connections
      where (requester_id = v_a and receiver_id = v_c) or (requester_id = v_c and receiver_id = v_a)
    ) then
      -- Left pending on purpose — lets you test the Requests tab's
      -- accept/decline flow from account C.
      insert into connections (requester_id, receiver_id, status) values (v_c, v_a, 'pending');
    end if;
  end if;

  -- ==========================================================================
  -- A direct conversation + a few messages between A and B
  -- ==========================================================================

  select conv.id into v_direct_conv_id
  from conversations conv
  join conversation_members m1 on m1.conversation_id = conv.id and m1.profile_id = v_a
  join conversation_members m2 on m2.conversation_id = conv.id and m2.profile_id = v_b
  where conv.conversation_type = 'direct'
  limit 1;

  if v_direct_conv_id is null then
    insert into conversations (conversation_type) values ('direct') returning id into v_direct_conv_id;
    insert into conversation_members (conversation_id, profile_id) values (v_direct_conv_id, v_a), (v_direct_conv_id, v_b);
  end if;

  if not exists (select 1 from messages where conversation_id = v_direct_conv_id) then
    insert into messages (conversation_id, sender_id, message_type, content, created_at) values
      (v_direct_conv_id, v_a, 'text', 'Hey! Excited for the hackathon 👋', now() - interval '10 minutes'),
      (v_direct_conv_id, v_b, 'text', 'Same here, let''s team up', now() - interval '8 minutes'),
      (v_direct_conv_id, v_a, 'text', 'Deal. I''ll post the team requirement.', now() - interval '5 minutes');
  end if;

  -- ==========================================================================
  -- A hackathon + team requirement (A owns it, B is a member) + its chat
  -- ==========================================================================

  select id into v_hackathon_id from hackathons where lower(name) = lower('Test Data Hackathon');
  if v_hackathon_id is null then
    insert into hackathons (name, event_date, created_by)
    values ('Test Data Hackathon', current_date + interval '14 days', v_a)
    returning id into v_hackathon_id;
  end if;

  select id into v_team_id from hackathon_team_requirements
  where hackathon_id = v_hackathon_id and creator_id = v_a and team_name = 'Test Data Team';
  if v_team_id is null then
    insert into hackathon_team_requirements (hackathon_id, creator_id, team_name, description, team_size)
    values (v_hackathon_id, v_a, 'Test Data Team', 'Seeded for local testing.', 4)
    returning id into v_team_id;

    insert into hackathon_team_members (team_requirement_id, profile_id) values (v_team_id, v_a);
  end if;

  if not exists (select 1 from hackathon_team_members where team_requirement_id = v_team_id and profile_id = v_b) then
    insert into hackathon_team_members (team_requirement_id, profile_id) values (v_team_id, v_b);
  end if;

  select id into v_team_conv_id from conversations where team_requirement_id = v_team_id;
  if v_team_conv_id is null then
    insert into conversations (conversation_type, team_requirement_id) values ('team', v_team_id) returning id into v_team_conv_id;
  end if;

  insert into conversation_members (conversation_id, profile_id)
  select v_team_conv_id, profile_id from hackathon_team_members where team_requirement_id = v_team_id
  on conflict do nothing;

  if not exists (select 1 from messages where conversation_id = v_team_conv_id) then
    insert into messages (conversation_id, sender_id, message_type, content, created_at)
    values (v_team_conv_id, v_a, 'text', 'Welcome to the team chat!', now() - interval '2 minutes');
  end if;

  raise notice 'Seeded test data between % and % (and % if present).', v_a, v_b, v_c;
end $$;
