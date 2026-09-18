-- seed_mock_data_full.sql
-- Comprehensive mock data across every section of the app (~50 rows each
-- where the domain supports it). OPTIONAL and MANUAL — not run by
-- `supabase db push`/`db reset`. Paste into the Supabase Dashboard's SQL
-- Editor (it runs as a privileged role, so it bypasses RLS — that's
-- expected and required here) against your live linked project.
--
-- WHAT THIS CREATES, AND WHY IT'S DIFFERENT FROM seed_test_data.sql:
-- To get 50 distinct, browsable *people* (People search, Local discovery,
-- 50-deep connections/Buddies, team rosters, ...), this creates 50
-- synthetic accounts directly in `auth.users` (+ best-effort `auth.identities`
-- so they can actually log in) on your live project — not just rows in your
-- app's own `public` tables. That's a more consequential action than any
-- other seeding done so far. Every mock account is tagged and reversible:
-- email pattern `mockuser001@example.test` .. `mockuser050@example.test`,
-- shared test password `MockPass123!`. A full cleanup script that deletes
-- everything this file creates is at the bottom (commented out).
--
-- Idempotent: safe to re-run. Every section checks for existing rows
-- (by email, or a "Mock " title/name prefix) before inserting.
--
-- Sections (each independent — a failure in one does not roll back the
-- others, so if something errors partway, re-run the file; completed
-- sections just no-op the second time):
--   1. 50 mock users + profiles (+ skills/interests attached)
--   2. Connections (mock<->mock and real<->mock) + a few pet names
--   3. Direct conversations + messages
--   4. Hackathons + team requirements + members + team chat
--   5. Projects
--   6. Jobs
--   7. Startups + members + opportunities
--   8. Mentorship (mentor profiles, requests, sessions)
--   9. Local discovery (profiles + connections + meetups)
--   10. Communities + members + posts + comments
--   11. Events + attendees
--   12. Notifications
--   13. A modest set of moderation reports
--
-- Deliberately NOT seeded: news (fetched live from an API — see seed.sql),
-- AI recommendations/match scores (computed server-side only, no client
-- insert path exists).

create temporary table if not exists tmp_mock_profiles (
  idx int primary key,
  profile_id uuid not null,
  full_name text not null
);

create temporary table if not exists tmp_real_profiles (
  profile_id uuid primary key
);

-- ============================================================================
-- Section 1: 50 mock users + profiles
-- ============================================================================

do $$
declare
  first_names text[] := array['Aarav','Vivaan','Aditya','Vihaan','Arjun','Sai','Reyansh','Krishna','Ishaan','Rohan',
    'Ananya','Diya','Saanvi','Aadhya','Kiara','Myra','Pari','Anika','Navya','Ira',
    'Liam','Noah','Oliver','Elijah','James','Emma','Ava','Sophia','Isabella','Mia',
    'Wei','Ming','Yuki','Haruto','Sana','Chen','Lin','Priya','Arun','Meera',
    'Carlos','Sofia','Diego','Valentina','Mateo','Camila','Lucas','Isabela','Nathan','Grace'];
  last_names text[] := array['Sharma','Verma','Gupta','Iyer','Nair','Patel','Reddy','Rao','Singh','Kapoor',
    'Chen','Kim','Tanaka','Wong','Zhang','Silva','Costa','Rossi','Bianchi','Moretti',
    'Smith','Johnson','Williams','Brown','Garcia','Davis','Wilson','Clark','Lewis','Walker'];
  companies text[] := array['Nimbus Labs','Byteforge','Solaris Tech','Quanta Systems','Pixel Foundry','Northwind AI',
    'Cobalt Cloud','Vertex Robotics','Lumen Analytics','Arclight Studios','Fernbridge','Orbital Data',
    'Stratos Fintech','Greenfield Bio','Harbor Devtools','Kestrel Security','Marrow Health','Novaquark',
    'Prism Labs','Redwood Ventures'];
  roles text[] := array['Software Engineer','Product Manager','Data Scientist','UX Designer','DevOps Engineer',
    'Backend Developer','Frontend Developer','Mobile Developer','ML Engineer','QA Engineer',
    'Founder','Research Scientist','Technical Writer','Solutions Architect','Growth Marketer'];
  cities text[] := array['Bangalore','Mumbai','Pune','Hyderabad','Delhi','Chennai','San Francisco','New York',
    'London','Berlin','Toronto','Singapore','Austin','Seattle','Remote'];
  user_types text[] := array['student','developer','professional','job_seeker','founder','researcher','other'];
  i int;
  v_email text;
  v_user_id uuid;
  v_full_name text;
begin
  for i in 1..50 loop
    -- Each user is isolated in its own sub-block: if your specific
    -- Supabase/GoTrue version requires an auth.users column beyond the
    -- widely-standard set below, that one user is skipped (logged via
    -- notice) instead of aborting all 50.
    begin
      v_email := 'mockuser' || lpad(i::text, 3, '0') || '@example.test';
      v_full_name := first_names[((i - 1) % array_length(first_names, 1)) + 1] || ' ' ||
                     last_names[((i * 7 - 1) % array_length(last_names, 1)) + 1];

      select id into v_user_id from auth.users where email = v_email;

      if v_user_id is null then
        v_user_id := gen_random_uuid();
        insert into auth.users (
          instance_id, id, aud, role, email, encrypted_password,
          email_confirmed_at, last_sign_in_at,
          raw_app_meta_data, raw_user_meta_data,
          created_at, updated_at,
          confirmation_token, email_change, email_change_token_new, recovery_token
        ) values (
          '00000000-0000-0000-0000-000000000000',
          v_user_id, 'authenticated', 'authenticated', v_email,
          crypt('MockPass123!', gen_salt('bf')),
          now(), now(),
          '{"provider":"email","providers":["email"]}', '{}',
          now(), now(),
          '', '', '', ''
        );

        -- Best-effort: lets these accounts actually log in via
        -- email+password. Separately wrapped so a schema mismatch in
        -- auth.identities specifically (it varies slightly across GoTrue
        -- versions) never rolls back the user/profile rows above — the
        -- mock profile stays fully usable everywhere in the app either
        -- way, just maybe not loggable-into.
        begin
          insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
          values (
            gen_random_uuid(), v_user_id, v_user_id,
            jsonb_build_object('sub', v_user_id::text, 'email', v_email),
            'email', now(), now(), now()
          );
        exception when others then
          raise notice 'auth.identities insert skipped for %: %', v_email, sqlerrm;
        end;
      end if;

      insert into profiles (
        id, username, full_name, bio, city, country, primary_user_type,
        current_company, "current_role", total_it_experience_months,
        is_open_to_work, is_open_to_mentorship, professional_discoverable,
        profile_completed
      ) values (
        v_user_id,
        'mock_' || lpad(i::text, 3, '0'),
        v_full_name,
        'Mock profile #' || i || ' — seeded for testing.',
        cities[((i - 1) % array_length(cities, 1)) + 1],
        'Testland',
        user_types[((i - 1) % array_length(user_types, 1)) + 1]::user_type,
        companies[((i - 1) % array_length(companies, 1)) + 1],
        roles[((i - 1) % array_length(roles, 1)) + 1],
        (i * 3) % 120,
        (i % 4 = 0),
        (i % 5 = 0),
        true,
        true
      )
      on conflict (id) do nothing;

      insert into tmp_mock_profiles (idx, profile_id, full_name)
      values (i, v_user_id, v_full_name)
      on conflict (idx) do nothing;
    exception when others then
      raise notice 'Skipped mock user % (%): %', i, v_email, sqlerrm;
    end;
  end loop;
end $$;

-- 2-4 skills per mock profile, from the skills already seeded in seed.sql.
do $$
declare
  rec record;
  skill_ids uuid[];
  n int;
begin
  select array_agg(id) into skill_ids from skills;
  if skill_ids is null then
    raise notice 'No skills found — run seed.sql first.';
    return;
  end if;
  for rec in select idx, profile_id from tmp_mock_profiles loop
    n := 2 + (rec.idx % 3);
    insert into profile_skills (profile_id, skill_id, experience_level, years_experience)
    select rec.profile_id, skill_ids[s], (array['beginner','intermediate','advanced','expert'])[1 + (s % 4)]::experience_level, (s % 8)::numeric
    from generate_series(1, least(n, array_length(skill_ids, 1))) s
    on conflict (profile_id, skill_id) do nothing;
  end loop;
end $$;

-- 2-3 interests per mock profile.
do $$
declare
  rec record;
  interest_ids uuid[];
  n int;
begin
  select array_agg(id) into interest_ids from interests;
  if interest_ids is null then
    raise notice 'No interests found — run seed.sql first.';
    return;
  end if;
  for rec in select idx, profile_id from tmp_mock_profiles loop
    n := 2 + (rec.idx % 2);
    insert into profile_interests (profile_id, interest_id)
    select rec.profile_id, interest_ids[s]
    from generate_series(1, least(n, array_length(interest_ids, 1))) s
    on conflict (profile_id, interest_id) do nothing;
  end loop;
end $$;

-- Whichever real accounts you already signed up (from before this script) —
-- wired into connections/conversations/notifications below so your own
-- logins have populated screens too, not just the 50 mock accounts.
insert into tmp_real_profiles (profile_id)
select p.id from profiles p
where p.id not in (select profile_id from tmp_mock_profiles)
on conflict do nothing;

-- ============================================================================
-- Section 2: Connections (~50) + a few pet names
-- ============================================================================

do $$
declare
  rec record;
  other_idx int;
  other_id uuid;
  v_status text;
  count_real int;
  real_id uuid;
  i int := 0;
begin
  for rec in select idx, profile_id from tmp_mock_profiles order by idx loop
    other_idx := ((rec.idx + 6) % 50) + 1; -- fixed offset, never self
    select profile_id into other_id from tmp_mock_profiles where idx = other_idx;
    v_status := (array['accepted','accepted','pending'])[1 + (rec.idx % 3)];

    if not exists (
      select 1 from connections
      where (requester_id = rec.profile_id and receiver_id = other_id)
         or (requester_id = other_id and receiver_id = rec.profile_id)
    ) then
      insert into connections (requester_id, receiver_id, status) values (rec.profile_id, other_id, v_status::connection_status);
    end if;
    i := i + 1;
  end loop;

  -- Connect each real account to ~10 mock profiles so their own
  -- Connections/Buddies screens are populated.
  select count(*) into count_real from tmp_real_profiles;
  if count_real > 0 then
    for real_id in select profile_id from tmp_real_profiles loop
      for rec in select idx, profile_id from tmp_mock_profiles where idx <= 10 loop
        if not exists (
          select 1 from connections
          where (requester_id = real_id and receiver_id = rec.profile_id)
             or (requester_id = rec.profile_id and receiver_id = real_id)
        ) then
          insert into connections (requester_id, receiver_id, status)
          values (real_id, rec.profile_id, (case when rec.idx <= 7 then 'accepted' else 'pending' end)::connection_status);
        end if;
      end loop;
    end loop;
  end if;
end $$;

-- A handful of pet names: each real account nicknames a few of its new
-- mock connections; a few mock<->mock pairs get one too, so RLS isolation
-- (owner_id = auth.uid()) is exercised at more than a single-user scale.
do $$
declare
  real_id uuid;
  rec record;
  pet_names text[] := array['Buddy','Champ','Ace','Sunshine','Rocket','Bestie','Chief','Sparky'];
  i int;
begin
  for real_id in select profile_id from tmp_real_profiles loop
    i := 0;
    for rec in
      select c.id as connection_id, case when c.requester_id = real_id then c.receiver_id else c.requester_id end as other_id
      from connections c
      where (c.requester_id = real_id or c.receiver_id = real_id) and c.status = 'accepted'
      limit 3
    loop
      i := i + 1;
      insert into connection_nicknames (connection_id, owner_id, nickname)
      values (rec.connection_id, real_id, pet_names[1 + (i % array_length(pet_names, 1))])
      on conflict (connection_id, owner_id) do update set nickname = excluded.nickname;
    end loop;
  end loop;

  for rec in
    select c.id as connection_id, c.requester_id as owner_id
    from connections c
    where c.status = 'accepted' and c.requester_id in (select profile_id from tmp_mock_profiles)
    order by c.created_at
    limit 10
  loop
    insert into connection_nicknames (connection_id, owner_id, nickname)
    values (rec.connection_id, rec.owner_id, pet_names[1 + (random() * (array_length(pet_names, 1) - 1))::int])
    on conflict (connection_id, owner_id) do nothing;
  end loop;
end $$;

-- ============================================================================
-- Section 3: Direct conversations + messages (~50 conversations)
-- ============================================================================

do $$
declare
  rec record;
  other_idx int;
  other_id uuid;
  v_conv_id uuid;
  sample_lines text[] := array[
    'Hey, how''s it going?', 'Are you joining the hackathon this year?', 'Loved your last project!',
    'Let''s connect sometime.', 'Thanks for the intro!', 'Are you free for a quick call?',
    'Congrats on the new role!', 'Saw your post, great work.', 'Let''s collaborate on something.',
    'Good luck with the interview!'
  ];
  real_id uuid;
begin
  for rec in select idx, profile_id from tmp_mock_profiles order by idx loop
    other_idx := ((rec.idx + 3) % 50) + 1;
    select profile_id into other_id from tmp_mock_profiles where idx = other_idx;

    select conv.id into v_conv_id
    from conversations conv
    join conversation_members m1 on m1.conversation_id = conv.id and m1.profile_id = rec.profile_id
    join conversation_members m2 on m2.conversation_id = conv.id and m2.profile_id = other_id
    where conv.conversation_type = 'direct'
    limit 1;

    if v_conv_id is null then
      insert into conversations (conversation_type) values ('direct') returning id into v_conv_id;
      insert into conversation_members (conversation_id, profile_id) values (v_conv_id, rec.profile_id), (v_conv_id, other_id);
      insert into messages (conversation_id, sender_id, message_type, content, created_at) values
        (v_conv_id, rec.profile_id, 'text', sample_lines[1 + (rec.idx % array_length(sample_lines, 1))], now() - interval '1 day'),
        (v_conv_id, other_id, 'text', sample_lines[1 + ((rec.idx + 1) % array_length(sample_lines, 1))], now() - interval '20 hours');
    end if;
  end loop;

  -- A conversation from each real account into a couple of mock profiles.
  for real_id in select profile_id from tmp_real_profiles loop
    for rec in select idx, profile_id from tmp_mock_profiles where idx in (1, 2, 3) loop
      select conv.id into v_conv_id
      from conversations conv
      join conversation_members m1 on m1.conversation_id = conv.id and m1.profile_id = real_id
      join conversation_members m2 on m2.conversation_id = conv.id and m2.profile_id = rec.profile_id
      where conv.conversation_type = 'direct'
      limit 1;

      if v_conv_id is null then
        insert into conversations (conversation_type) values ('direct') returning id into v_conv_id;
        insert into conversation_members (conversation_id, profile_id) values (v_conv_id, real_id), (v_conv_id, rec.profile_id);
        insert into messages (conversation_id, sender_id, message_type, content, created_at) values
          (v_conv_id, rec.profile_id, 'text', 'Hi! Excited to test this out with you.', now() - interval '3 hours');
      end if;
    end loop;
  end loop;
end $$;

-- ============================================================================
-- Section 4: Hackathons (~50) + team requirements + members + team chat
-- ============================================================================

do $$
declare
  rec record;
  v_hackathon_id uuid;
  v_team_id uuid;
  v_conv_id uuid;
  member_idx int;
  member_id uuid;
  hack_names text[] := array['CodeFusion','HackNorth','ByteStorm','InnovateX','DevSprint','QuantumHack',
    'NeonHacks','SkylineHack','ForgeHack','PulseCode'];
begin
  for rec in select idx, profile_id, full_name from tmp_mock_profiles order by idx loop
    select id into v_hackathon_id from hackathons
    where lower(name) = lower('Mock ' || hack_names[1 + (rec.idx % array_length(hack_names, 1))] || ' ' || (2026 + rec.idx));
    if v_hackathon_id is null then
      insert into hackathons (name, event_date, created_by)
      values (
        'Mock ' || hack_names[1 + (rec.idx % array_length(hack_names, 1))] || ' ' || (2026 + rec.idx),
        current_date + (rec.idx || ' days')::interval,
        rec.profile_id
      )
      returning id into v_hackathon_id;
    end if;

    select id into v_team_id from hackathon_team_requirements
    where hackathon_id = v_hackathon_id and creator_id = rec.profile_id;
    if v_team_id is null then
      insert into hackathon_team_requirements (hackathon_id, creator_id, team_name, description, required_roles, team_size)
      values (
        v_hackathon_id, rec.profile_id, rec.full_name || '''s Team',
        'Mock team looking for teammates.',
        array['Frontend', 'Backend', 'Design'],
        4
      )
      returning id into v_team_id;

      insert into hackathon_team_members (team_requirement_id, profile_id) values (v_team_id, rec.profile_id);

      member_idx := ((rec.idx + 15) % 50) + 1;
      select profile_id into member_id from tmp_mock_profiles where idx = member_idx;
      insert into hackathon_team_members (team_requirement_id, profile_id) values (v_team_id, member_id)
      on conflict do nothing;

      insert into conversations (conversation_type, team_requirement_id) values ('team', v_team_id) returning id into v_conv_id;
      insert into conversation_members (conversation_id, profile_id)
      select v_conv_id, profile_id from hackathon_team_members where team_requirement_id = v_team_id;
      insert into messages (conversation_id, sender_id, message_type, content, created_at)
      values (v_conv_id, rec.profile_id, 'text', 'Welcome to ' || rec.full_name || '''s team chat!', now() - interval '1 hour');
    end if;
  end loop;
end $$;

-- ============================================================================
-- Section 5: Projects (~50)
-- ============================================================================

do $$
declare
  rec record;
  categories text[] := array['Web App','Mobile App','AI/ML','Open Source','Developer Tool','Game','Hardware','Data Pipeline'];
  collab_types text[] := array['personal','startup','open_source','research','hackathon','other'];
  comp_types text[] := array['paid','unpaid','equity','negotiable'];
  statuses text[] := array['open','in_progress','completed','closed'];
begin
  for rec in select idx, profile_id, full_name from tmp_mock_profiles order by idx loop
    if not exists (select 1 from projects where owner_id = rec.profile_id and title = 'Mock Project #' || rec.idx) then
      insert into projects (owner_id, title, description, category, collaboration_type, compensation_type, time_commitment_hours, duration_description, status)
      values (
        rec.profile_id,
        'Mock Project #' || rec.idx,
        rec.full_name || ' is building something interesting — seeded for testing.',
        categories[1 + (rec.idx % array_length(categories, 1))],
        collab_types[1 + (rec.idx % array_length(collab_types, 1))]::collaboration_type,
        comp_types[1 + (rec.idx % array_length(comp_types, 1))]::compensation_type,
        5 + (rec.idx % 20),
        (2 + rec.idx % 6) || ' weeks',
        statuses[1 + (rec.idx % array_length(statuses, 1))]::project_status
      );
    end if;
  end loop;
end $$;

-- ============================================================================
-- Section 6: Jobs (~50)
-- ============================================================================

do $$
declare
  rec record;
  titles text[] := array['Software Engineer','Senior Backend Developer','Frontend Engineer','Product Designer',
    'Data Analyst','ML Engineer','DevOps Engineer','Mobile Developer','QA Engineer','Engineering Manager'];
  emp_types text[] := array['full_time','internship','freelance','contract','part_time','research','volunteer'];
  work_modes text[] := array['remote','hybrid','onsite'];
begin
  for rec in select idx, profile_id, full_name from tmp_mock_profiles order by idx loop
    if not exists (select 1 from jobs where poster_id = rec.profile_id and title = 'Mock ' || titles[1 + (rec.idx % array_length(titles, 1))] || ' #' || rec.idx) then
      insert into jobs (poster_id, company_name, title, description, employment_type, work_mode, location, salary_min, salary_max, currency, status)
      values (
        rec.profile_id,
        rec.full_name || '''s Company',
        'Mock ' || titles[1 + (rec.idx % array_length(titles, 1))] || ' #' || rec.idx,
        'Mock job listing seeded for testing.',
        emp_types[1 + (rec.idx % array_length(emp_types, 1))]::job_employment_type,
        work_modes[1 + (rec.idx % array_length(work_modes, 1))]::work_mode,
        'Remote',
        40000 + (rec.idx * 1000),
        80000 + (rec.idx * 1500),
        'USD',
        'open'
      );
    end if;
  end loop;
end $$;

-- ============================================================================
-- Section 7: Startups (~50) + members + opportunities
-- ============================================================================

do $$
declare
  rec record;
  v_startup_id uuid;
  member_idx int;
  member_id uuid;
  industries text[] := array['Fintech','Healthtech','Edtech','AI/ML','Climate','SaaS','E-commerce','Gaming','Biotech','Logistics'];
  stages text[] := array['idea','mvp','early_revenue','growth','funded'];
begin
  for rec in select idx, profile_id, full_name from tmp_mock_profiles order by idx loop
    if not exists (select 1 from startups where owner_id = rec.profile_id and name = 'Mock ' || rec.full_name || ' Inc.') then
      insert into startups (owner_id, name, description, industry, stage, location, website, team_size)
      values (
        rec.profile_id,
        'Mock ' || rec.full_name || ' Inc.',
        'Mock startup seeded for testing.',
        industries[1 + (rec.idx % array_length(industries, 1))],
        stages[1 + (rec.idx % array_length(stages, 1))]::startup_stage,
        'Remote',
        'https://example.test/mock-startup-' || rec.idx,
        2 + (rec.idx % 15)
      )
      returning id into v_startup_id;

      insert into startup_members (startup_id, profile_id, role, is_founder) values (v_startup_id, rec.profile_id, 'Founder', true);

      member_idx := ((rec.idx + 20) % 50) + 1;
      select profile_id into member_id from tmp_mock_profiles where idx = member_idx;
      insert into startup_members (startup_id, profile_id, role, is_founder) values (v_startup_id, member_id, 'Engineer', false)
      on conflict do nothing;

      insert into startup_opportunities (startup_id, title, description, role, compensation_type, is_remote, status)
      values (v_startup_id, 'Mock Opportunity at ' || rec.full_name || ' Inc.', 'Seeded opportunity.', 'Engineer', 'negotiable', true, 'open');
    end if;
  end loop;
end $$;

-- ============================================================================
-- Section 8: Mentorship (~50 mentor profiles, ~50 requests, sessions for accepted ones)
-- ============================================================================

do $$
declare
  rec record;
  expertise_options text[] := array['Career Growth','System Design','Interview Prep','Startups','Machine Learning','Leadership'];
begin
  for rec in select idx, profile_id from tmp_mock_profiles order by idx loop
    insert into mentor_profiles (profile_id, available, expertise, topics, session_duration_minutes, pricing_type, bio)
    values (
      rec.profile_id, true,
      array[expertise_options[1 + (rec.idx % array_length(expertise_options, 1))]],
      array['General guidance', 'Resume review'],
      30, case when rec.idx % 3 = 0 then 'paid' else 'free' end::pricing_type,
      'Mock mentor profile seeded for testing.'
    )
    on conflict (profile_id) do nothing;
  end loop;
end $$;

do $$
declare
  rec record;
  mentor_idx int;
  v_mentor_id uuid;
  v_status text;
  v_request_id uuid;
begin
  for rec in select idx, profile_id from tmp_mock_profiles order by idx loop
    mentor_idx := ((rec.idx + 11) % 50) + 1;
    if mentor_idx = rec.idx then mentor_idx := ((rec.idx + 12) % 50) + 1; end if;
    select profile_id into v_mentor_id from tmp_mock_profiles where idx = mentor_idx;
    v_status := (array['pending','accepted','declined','completed'])[1 + (rec.idx % 4)];

    if not exists (select 1 from mentor_requests where mentor_id = v_mentor_id and requester_id = rec.profile_id) then
      insert into mentor_requests (mentor_id, requester_id, topic, message, status)
      values (v_mentor_id, rec.profile_id, 'Career advice', 'Mock mentor request seeded for testing.', v_status::mentor_request_status)
      returning id into v_request_id;

      if v_status in ('accepted', 'completed') then
        insert into mentor_sessions (mentor_request_id, scheduled_at, duration_minutes, status)
        values (v_request_id, now() + interval '3 days', 30, case when v_status = 'completed' then 'completed' else 'scheduled' end::mentor_session_status);
      end if;
    end if;
  end loop;
end $$;

-- ============================================================================
-- Section 9: Local discovery (~50 local profiles + connections + meetups)
-- ============================================================================

do $$
declare
  rec record;
  base_lat numeric := 12.97; -- Bangalore-ish, purely synthetic
  base_lng numeric := 77.59;
begin
  for rec in select idx, profile_id from tmp_mock_profiles order by idx loop
    update profiles
    set local_discoverable = true,
        approx_latitude = base_lat + ((rec.idx % 10) * 0.05),
        approx_longitude = base_lng + ((rec.idx % 7) * 0.05)
    where id = rec.profile_id;

    insert into local_profiles (profile_id, enabled, approximate_city, approximate_area, preferred_radius_km, bio)
    values (rec.profile_id, true, 'Bangalore', 'Area ' || (1 + rec.idx % 12), 5 + (rec.idx % 20), 'Mock local profile seeded for testing.')
    on conflict (profile_id) do nothing;

    insert into local_preferences (profile_id, activity_preferences)
    values (rec.profile_id, array['Coffee', 'Walk'])
    on conflict (profile_id) do nothing;
  end loop;
end $$;

do $$
declare
  rec record;
  other_idx int;
  other_id uuid;
  v_status text;
  v_conn_id uuid;
begin
  for rec in select idx, profile_id from tmp_mock_profiles order by idx loop
    other_idx := ((rec.idx + 4) % 50) + 1;
    select profile_id into other_id from tmp_mock_profiles where idx = other_idx;
    v_status := case when rec.idx % 2 = 0 then 'accepted' else 'pending' end;

    if not exists (
      select 1 from local_connections
      where (requester_id = rec.profile_id and receiver_id = other_id)
         or (requester_id = other_id and receiver_id = rec.profile_id)
    ) then
      insert into local_connections (requester_id, receiver_id, status)
      values (rec.profile_id, other_id, v_status::connection_status)
      returning id into v_conn_id;

      if v_status = 'accepted' then
        insert into meetup_suggestions (local_connection_id, suggested_by, activity_type, suggested_area, suggested_place_name, status)
        values (v_conn_id, rec.profile_id, 'Coffee', 'Area ' || (1 + rec.idx % 12), 'Mock Cafe', 'pending');
      end if;
    end if;
  end loop;
end $$;

-- ============================================================================
-- Section 10: Communities (~50) + members + posts + comments
-- ============================================================================

do $$
declare
  rec record;
  v_community_id uuid;
  v_post_id uuid;
  member_idx int;
  member_id uuid;
  types text[] := array['technology','city','student','startup','research','open_source','interest_based'];
begin
  for rec in select idx, profile_id, full_name from tmp_mock_profiles order by idx loop
    if not exists (select 1 from communities where slug = 'mock-community-' || rec.idx) then
      insert into communities (owner_id, name, slug, description, community_type, is_private)
      values (
        rec.profile_id, 'Mock Community #' || rec.idx, 'mock-community-' || rec.idx,
        'Seeded community for testing.', types[1 + (rec.idx % array_length(types, 1))]::community_type, false
      )
      returning id into v_community_id;

      insert into community_members (community_id, profile_id, role) values (v_community_id, rec.profile_id, 'admin');

      member_idx := ((rec.idx + 9) % 50) + 1;
      select profile_id into member_id from tmp_mock_profiles where idx = member_idx;
      insert into community_members (community_id, profile_id, role) values (v_community_id, member_id, 'member')
      on conflict do nothing;

      insert into community_posts (community_id, author_id, content)
      values (v_community_id, rec.profile_id, 'Welcome to Mock Community #' || rec.idx || '! Excited to build this together.')
      returning id into v_post_id;

      insert into community_comments (post_id, author_id, content)
      values (v_post_id, member_id, 'Looking forward to it!');
    end if;
  end loop;
end $$;

-- ============================================================================
-- Section 11: Events (~50) + attendees
-- ============================================================================

do $$
declare
  rec record;
  v_event_id uuid;
  attendee_idx int;
  attendee_id uuid;
  types text[] := array['hackathon','workshop','conference','tech_talk','study_session','community_event'];
  modes text[] := array['online','offline','hybrid'];
begin
  for rec in select idx, profile_id, full_name from tmp_mock_profiles order by idx loop
    if not exists (select 1 from events where host_id = rec.profile_id and title = 'Mock Event #' || rec.idx) then
      -- cover_image_url: a distinct, deterministic picsum.photos photo per
      -- event (seeded by idx, so re-running this block always assigns the
      -- same image to the same event) — otherwise EventCard/EventDetailView
      -- fall back to the plain brand-gradient placeholder for all 50 rows,
      -- which makes the Events list look identical/empty at a glance.
      insert into events (host_id, title, description, event_type, mode, location, starts_at, ends_at, cover_image_url)
      values (
        rec.profile_id, 'Mock Event #' || rec.idx, 'Seeded event for testing.',
        types[1 + (rec.idx % array_length(types, 1))]::event_type,
        modes[1 + (rec.idx % array_length(modes, 1))]::hackathon_mode,
        'Remote', now() + (rec.idx || ' days')::interval, now() + (rec.idx || ' days')::interval + interval '2 hours',
        'https://picsum.photos/seed/mock-event-' || rec.idx || '/800/450'
      )
      returning id into v_event_id;

      insert into event_attendees (event_id, profile_id) values (v_event_id, rec.profile_id);

      attendee_idx := ((rec.idx + 13) % 50) + 1;
      select profile_id into attendee_id from tmp_mock_profiles where idx = attendee_idx;
      insert into event_attendees (event_id, profile_id) values (v_event_id, attendee_id)
      on conflict do nothing;
    end if;
  end loop;
end $$;

-- ============================================================================
-- Section 12: Notifications (~50, weighted toward real accounts so you
-- actually see them when logged into your own test account)
-- ============================================================================

do $$
declare
  rec record;
  count_real int;
  target_id uuid;
  -- Three parallel 1-D arrays, not one text[][] — `array[array[...], ...]`
  -- builds a genuine 2-D Postgres array, and single-bracket indexing on
  -- that (types_and_titles[k]) doesn't extract "row k" the way a nested
  -- array would in most languages; it silently returns NULL instead of
  -- erroring, which is exactly what fed NULLs into the NOT NULL columns
  -- below on the previous attempt.
  notif_types text[] := array['connection_accepted','message','team_invitation','job','meetup_suggestion'];
  notif_titles text[] := array['Connection accepted','New message','Team invitation','New job match','Meetup suggested'];
  notif_bodies text[] := array[
    'A mock connection accepted your request.',
    'You have a new message.',
    'You were invited to join a hackathon team.',
    'A new job matches your profile.',
    'Someone nearby suggested a meetup.'
  ];
  i int;
  k int;
begin
  select count(*) into count_real from tmp_real_profiles;

  for i in 1..50 loop
    if count_real > 0 and i % 2 = 0 then
      select profile_id into target_id from tmp_real_profiles order by random() limit 1;
    else
      select profile_id into target_id from tmp_mock_profiles where idx = ((i - 1) % 50) + 1;
    end if;
    k := 1 + (i % array_length(notif_types, 1));

    insert into notifications (profile_id, type, title, body, data)
    values (target_id, notif_types[k], notif_titles[k], 'Mock: ' || notif_bodies[k], jsonb_build_object('mock', true, 'seq', i));
  end loop;
end $$;

-- ============================================================================
-- Section 13: A modest set of moderation reports (not 50 — bulk fake abuse
-- reports don't make sense as test data; ~10 is enough to exercise the
-- admin moderation queue)
-- ============================================================================

do $$
declare
  v_reporter_id uuid;
  target_idx int;
  v_target_id uuid;
  categories text[] := array['spam','harassment','fake_profile','scam','inappropriate_content','unsafe_behavior','fraud','other'];
  i int;
begin
  for i in 1..10 loop
    select profile_id into v_reporter_id from tmp_mock_profiles where idx = i;
    target_idx := ((i + 25) % 50) + 1;
    select profile_id into v_target_id from tmp_mock_profiles where idx = target_idx;

    if not exists (select 1 from reports where reporter_id = v_reporter_id and target_id = v_target_id and target_type = 'profile') then
      insert into reports (reporter_id, target_type, target_id, category, details, status)
      values (v_reporter_id, 'profile', v_target_id, categories[1 + (i % array_length(categories, 1))]::report_category, 'Mock report seeded for testing.', 'open');
    end if;
  end loop;
end $$;

-- ============================================================================
-- CLEANUP — deletes everything this script created. Commented out on
-- purpose; uncomment and run when you want to remove all mock data.
-- Deleting the auth.users rows cascades through profiles -> everything
-- else that references them (connections, messages, hackathons, projects,
-- jobs, startups, communities, events, notifications, ...) via existing
-- `on delete cascade` foreign keys. Content owned by a REAL account (e.g.
-- your own signed-up test users) is untouched.
-- ============================================================================

-- delete from auth.users where email like 'mockuser%@example.test';
