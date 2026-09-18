-- seed_hackathon_demo.sql
--
-- Purpose-built for the live "AI-Powered Intent Matching" demo — do NOT rely
-- on seed.sql/seed_mock_data_full.sql's randomly-generated people for the
-- judged run; a random draw can produce an empty or unconvincing match.
-- This creates exactly 3 hand-crafted profiles whose skills/interests are
-- deliberately complementary, so "Find Matches" on Priya's Intent always
-- produces a strong, explainable, well-ranked result:
--
--   Priya Sharma   — the demo's presenter-facing account. Posts an Intent:
--                     "Find Co-founder" needing Node.js/PostgreSQL/AWS.
--   Rahul Verma    — the TOP match: has all 3 needed skills, shares two
--                     interests with Priya, same experience level, and an
--                     overlapping availability slot — every scoring
--                     component lands high, and the real AI rationale (if
--                     AI_PROVIDER is configured) has a genuinely strong
--                     story to tell.
--   Ananya Iyer    — a deliberately WEAKER second match (1 of 3 skills, no
--                     shared interests, one experience level apart, no
--                     availability overlap) so the demo shows real ranking,
--                     not just one lonely result.
--
-- Rahul also has real, public activity — an "AI Builders (Demo)" community
-- he admins, an upcoming "Backend & AI Meetup (Demo)" event he's attending,
-- an open "Fintech Analytics Engine (Demo)" project he owns, and a recent
-- post — all tagged with the same skills Priya's Intent needs, so
-- get-network-recommendations (0052) has real signal to surface as
-- "Because of this match" cards. Every demo record's name/description says
-- "(Demo)" — never presented as real production activity.
--
-- OPTIONAL and MANUAL, like seed_mock_data_full.sql — not run by
-- `supabase db push`/`db reset`. Paste into the Supabase Dashboard's SQL
-- Editor against your linked project before rehearsing/running the demo.
-- Idempotent: safe to re-run (every insert is on-conflict-safe, and each
-- account's auth.users row is reused by email if it already exists — same
-- precedent as seed_mock_data_full.sql's per-user block, inlined three
-- times here rather than as a nested function, since PL/pgSQL doesn't
-- support defining a function inside a DO block).
--
-- Shared demo login password for all three: DemoPass123!
-- Emails: priya.demo@example.test / rahul.demo@example.test / ananya.demo@example.test

do $$
declare
  v_priya_id uuid;
  v_rahul_id uuid;
  v_ananya_id uuid;
  v_intent_id uuid;
  v_community_id uuid;
  v_event_id uuid;
  v_project_id uuid;
  v_skill_nodejs uuid;
  v_skill_postgres uuid;
  v_skill_aws uuid;
  v_skill_uiux uuid;
  v_skill_pm uuid;
  v_skill_docker uuid;
  v_skill_python uuid;
  v_skill_ml uuid;
  v_interest_startups uuid;
  v_interest_opensource uuid;
  v_interest_ml uuid;
  v_interest_ai uuid;
begin
  -- ==========================================================================
  -- Reuse the existing skills/interests catalog (seed.sql) — never invent
  -- new rows here; if seed.sql hasn't been run yet, this whole file no-ops
  -- with a clear notice rather than half-seeding.
  -- ==========================================================================
  select id into v_skill_nodejs from skills where normalized_name = 'nodejs';
  select id into v_skill_postgres from skills where normalized_name = 'postgresql';
  select id into v_skill_aws from skills where normalized_name = 'aws';
  select id into v_skill_uiux from skills where normalized_name = 'ui-ux-design';
  select id into v_skill_pm from skills where normalized_name = 'product-management';
  select id into v_skill_docker from skills where normalized_name = 'docker';
  select id into v_skill_python from skills where normalized_name = 'python';
  select id into v_skill_ml from skills where normalized_name = 'machine-learning';
  select id into v_interest_startups from interests where normalized_name = 'startups';
  select id into v_interest_opensource from interests where normalized_name = 'open-source';
  select id into v_interest_ml from interests where normalized_name = 'machine-learning';
  select id into v_interest_ai from interests where normalized_name = 'ai';

  if v_skill_nodejs is null or v_skill_postgres is null or v_skill_aws is null then
    raise notice 'Base skills catalog not found — run seed.sql first. Aborting demo seed.';
    return;
  end if;

  -- ==========================================================================
  -- Priya Sharma — the presenter's account
  -- ==========================================================================
  select id into v_priya_id from auth.users where email = 'priya.demo@example.test';
  if v_priya_id is null then
    v_priya_id := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, last_sign_in_at,
      raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_priya_id, 'authenticated', 'authenticated', 'priya.demo@example.test',
      crypt('DemoPass123!', gen_salt('bf')),
      now(), now(),
      '{"provider":"email","providers":["email"]}', '{}',
      now(), now(),
      '', '', '', ''
    );
    begin
      insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (
        gen_random_uuid(), v_priya_id, v_priya_id,
        jsonb_build_object('sub', v_priya_id::text, 'email', 'priya.demo@example.test'),
        'email', now(), now(), now()
      );
    exception when others then
      raise notice 'auth.identities insert skipped for priya.demo@example.test: %', sqlerrm;
    end;
  end if;

  insert into profiles (
    id, username, full_name, bio, city, country, primary_user_type,
    current_company, "current_role", total_it_experience_months,
    is_open_to_work, professional_discoverable, profile_completed
  ) values (
    v_priya_id, 'priya_demo', 'Priya Sharma',
    'Product designer turned builder. Prototyping a fintech idea and looking for a technical co-founder.',
    'Bangalore', 'India', 'founder', null, 'Product Designer', 48,
    false, true, true
  )
  on conflict (id) do update set full_name = excluded.full_name, bio = excluded.bio;

  insert into profile_skills (profile_id, skill_id, experience_level, years_experience) values
    (v_priya_id, v_skill_uiux, 'expert', 4),
    (v_priya_id, v_skill_pm, 'advanced', 3)
  on conflict (profile_id, skill_id) do nothing;

  insert into profile_interests (profile_id, interest_id) values
    (v_priya_id, v_interest_startups),
    (v_priya_id, v_interest_opensource)
  on conflict (profile_id, interest_id) do nothing;

  -- user_availability has no natural unique key (only its own random `id`),
  -- so a bare `on conflict do nothing` would never actually fire and this
  -- would duplicate rows on every re-run — guard with `where not exists`.
  insert into user_availability (profile_id, day_of_week, start_time, end_time)
  select v_priya_id, 1, '18:00', '20:00' -- Monday evening
  where not exists (
    select 1 from user_availability where profile_id = v_priya_id and day_of_week = 1 and start_time = '18:00'
  );

  -- One Intent, deliberately reset on every re-run so its needed-skills set
  -- always matches this file exactly (a demo Intent is meant to be defined
  -- entirely here, not edited by hand in between rehearsals).
  select id into v_intent_id from intents where profile_id = v_priya_id and title = 'Looking for a technical co-founder';
  if v_intent_id is not null then
    delete from intents where id = v_intent_id; -- cascades intent_skills
  end if;
  insert into intents (
    profile_id, intent_type, title, description, experience_level,
    visibility, status, expires_at
  ) values (
    v_priya_id, 'find_cofounder', 'Looking for a technical co-founder',
    'I''ve designed and validated a fintech product idea and need a backend-leaning technical co-founder to build it with me — Node.js/PostgreSQL/AWS.',
    'advanced', 'public', 'active', now() + interval '90 days'
  ) returning id into v_intent_id;

  insert into intent_skills (intent_id, skill_id, direction) values
    (v_intent_id, v_skill_nodejs, 'needed'),
    (v_intent_id, v_skill_postgres, 'needed'),
    (v_intent_id, v_skill_aws, 'needed')
  on conflict (intent_id, skill_id, direction) do nothing;

  -- ==========================================================================
  -- Rahul Verma — the strong match
  -- ==========================================================================
  select id into v_rahul_id from auth.users where email = 'rahul.demo@example.test';
  if v_rahul_id is null then
    v_rahul_id := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, last_sign_in_at,
      raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_rahul_id, 'authenticated', 'authenticated', 'rahul.demo@example.test',
      crypt('DemoPass123!', gen_salt('bf')),
      now(), now(),
      '{"provider":"email","providers":["email"]}', '{}',
      now(), now(),
      '', '', '', ''
    );
    begin
      insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (
        gen_random_uuid(), v_rahul_id, v_rahul_id,
        jsonb_build_object('sub', v_rahul_id::text, 'email', 'rahul.demo@example.test'),
        'email', now(), now(), now()
      );
    exception when others then
      raise notice 'auth.identities insert skipped for rahul.demo@example.test: %', sqlerrm;
    end;
  end if;

  insert into profiles (
    id, username, full_name, bio, city, country, primary_user_type,
    current_company, "current_role", total_it_experience_months,
    is_open_to_work, professional_discoverable, profile_completed
  ) values (
    v_rahul_id, 'rahul_demo', 'Rahul Verma',
    'Backend engineer who loves early-stage building. Open to the right co-founder opportunity.',
    'Bangalore', 'India', 'developer', 'Solaris Tech', 'Backend Engineer', 60,
    false, true, true
  )
  on conflict (id) do update set full_name = excluded.full_name, bio = excluded.bio;

  insert into profile_skills (profile_id, skill_id, experience_level, years_experience) values
    (v_rahul_id, v_skill_nodejs, 'expert', 5),
    (v_rahul_id, v_skill_postgres, 'advanced', 4),
    (v_rahul_id, v_skill_aws, 'advanced', 3),
    (v_rahul_id, v_skill_docker, 'advanced', 3)
  on conflict (profile_id, skill_id) do nothing;

  insert into profile_interests (profile_id, interest_id) values
    (v_rahul_id, v_interest_startups),
    (v_rahul_id, v_interest_opensource)
  on conflict (profile_id, interest_id) do nothing;

  insert into user_availability (profile_id, day_of_week, start_time, end_time)
  select v_rahul_id, 1, '19:00', '21:00' -- overlaps Priya's Monday 18:00-20:00
  where not exists (
    select 1 from user_availability where profile_id = v_rahul_id and day_of_week = 1 and start_time = '19:00'
  );

  -- --------------------------------------------------------------------------
  -- Rahul's visible, public activity — this is what powers the
  -- "Because of this match" cross-entity recommendations (0052) demoed
  -- alongside the person match itself: a community, an upcoming event, an
  -- open project, and a recent post, each tagged with the same skills
  -- Priya's Intent needs. All clearly demo data (owned by a *.demo@
  -- example.test account, named/described as such below) — never presented
  -- as real production activity.
  -- --------------------------------------------------------------------------

  insert into communities (owner_id, name, slug, description, community_type, is_private, access_type)
  values (
    v_rahul_id, 'AI Builders (Demo)', 'ai-builders-demo',
    'Demo community seeded for the Communeo Intelligence hackathon walkthrough — backend engineers and AI builders sharing what they''re working on.',
    'technology', false, 'public'
  )
  on conflict (slug) do update set name = excluded.name
  returning id into v_community_id;

  insert into community_members (community_id, profile_id, role)
  values (v_community_id, v_rahul_id, 'admin')
  on conflict (community_id, profile_id) do nothing;

  insert into community_topics (community_id, skill_id) values
    (v_community_id, v_skill_nodejs),
    (v_community_id, v_skill_aws)
  on conflict (community_id, skill_id) do nothing;

  -- Reset-and-recreate on every re-run, same reasoning as Priya's Intent
  -- above: a demo event should always be exactly what this file describes.
  delete from events where host_id = v_rahul_id and title = 'Backend & AI Meetup (Demo)';
  insert into events (host_id, title, description, event_type, mode, starts_at, ends_at, status, visibility, cover_image_url)
  values (
    v_rahul_id, 'Backend & AI Meetup (Demo)',
    'Demo event seeded for the Communeo Intelligence hackathon walkthrough.',
    'tech_talk', 'online', now() + interval '10 days', now() + interval '10 days' + interval '2 hours',
    'published', 'public', 'https://picsum.photos/seed/backend-ai-meetup/800/450'
  ) returning id into v_event_id;

  insert into event_attendees (event_id, profile_id) values (v_event_id, v_rahul_id)
  on conflict (event_id, profile_id) do nothing;

  insert into event_tags (event_id, skill_id) values
    (v_event_id, v_skill_nodejs),
    (v_event_id, v_skill_postgres)
  on conflict (event_id, skill_id) do nothing;

  delete from projects where owner_id = v_rahul_id and title = 'Fintech Analytics Engine (Demo)';
  insert into projects (owner_id, title, description, category, status)
  values (
    v_rahul_id, 'Fintech Analytics Engine (Demo)',
    'Demo project seeded for the Communeo Intelligence hackathon walkthrough — an open backend project needing exactly the skills Priya''s Intent asks for.',
    'FinTech', 'open'
  ) returning id into v_project_id;

  insert into project_required_skills (project_id, skill_id) values
    (v_project_id, v_skill_nodejs),
    (v_project_id, v_skill_postgres),
    (v_project_id, v_skill_aws)
  on conflict (project_id, skill_id) do nothing;

  insert into posts (author_id, content, category)
  select v_rahul_id,
    'Just shipped a Node.js + PostgreSQL pipeline for real-time fintech analytics on AWS. (Demo post seeded for the Communeo Intelligence hackathon walkthrough.)',
    'AWS'
  where not exists (
    select 1 from posts where author_id = v_rahul_id and content like 'Just shipped a Node.js%'
  );

  -- ==========================================================================
  -- Ananya Iyer — the weaker second match (for real ranking, not one result)
  -- ==========================================================================
  select id into v_ananya_id from auth.users where email = 'ananya.demo@example.test';
  if v_ananya_id is null then
    v_ananya_id := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, last_sign_in_at,
      raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_ananya_id, 'authenticated', 'authenticated', 'ananya.demo@example.test',
      crypt('DemoPass123!', gen_salt('bf')),
      now(), now(),
      '{"provider":"email","providers":["email"]}', '{}',
      now(), now(),
      '', '', '', ''
    );
    begin
      insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (
        gen_random_uuid(), v_ananya_id, v_ananya_id,
        jsonb_build_object('sub', v_ananya_id::text, 'email', 'ananya.demo@example.test'),
        'email', now(), now(), now()
      );
    exception when others then
      raise notice 'auth.identities insert skipped for ananya.demo@example.test: %', sqlerrm;
    end;
  end if;

  insert into profiles (
    id, username, full_name, bio, city, country, primary_user_type,
    current_company, "current_role", total_it_experience_months,
    is_open_to_work, professional_discoverable, profile_completed
  ) values (
    v_ananya_id, 'ananya_demo', 'Ananya Iyer',
    'Data scientist exploring ML applications in fintech.',
    'Pune', 'India', 'developer', 'Nimbus Labs', 'Data Scientist', 36,
    false, true, true
  )
  on conflict (id) do update set full_name = excluded.full_name, bio = excluded.bio;

  insert into profile_skills (profile_id, skill_id, experience_level, years_experience) values
    (v_ananya_id, v_skill_python, 'expert', 4),
    (v_ananya_id, v_skill_ml, 'advanced', 3),
    (v_ananya_id, v_skill_aws, 'intermediate', 1)
  on conflict (profile_id, skill_id) do nothing;

  insert into profile_interests (profile_id, interest_id) values
    (v_ananya_id, v_interest_ml),
    (v_ananya_id, v_interest_ai)
  on conflict (profile_id, interest_id) do nothing;

  insert into user_availability (profile_id, day_of_week, start_time, end_time)
  select v_ananya_id, 4, '09:00', '11:00' -- Thursday morning: no overlap with Priya
  where not exists (
    select 1 from user_availability where profile_id = v_ananya_id and day_of_week = 4 and start_time = '09:00'
  );

  raise notice 'Demo seed complete. Sign in as priya.demo@example.test / DemoPass123!, open the "Looking for a technical co-founder" Intent, and tap Find Matches. Rahul''s AI Builders (Demo) community/event/project/post should appear under "Because of this match".';
end $$;

-- To remove everything this file created (does not touch seed.sql/
-- seed_mock_data_full.sql's rows):
-- delete from auth.users where email in
--   ('priya.demo@example.test', 'rahul.demo@example.test', 'ananya.demo@example.test');
