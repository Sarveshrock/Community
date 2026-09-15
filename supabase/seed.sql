-- seed.sql
-- Safe development seed data. No production credentials, no real user data.

-- ============================================================================
-- Storage buckets
-- ============================================================================

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('project-images', 'project-images', true),
  ('startup-logos', 'startup-logos', true),
  ('chat-attachments', 'chat-attachments', false),
  ('community-media', 'community-media', true)
on conflict (id) do nothing;

-- avatars: any authenticated user may upload to their own folder (avatars/<uid>/...)
-- Postgres has no `create policy if not exists`, so each policy is dropped
-- first — this file is meant to be re-runnable against an already-seeded
-- database (e.g. after a `db push` that didn't touch these), not just once
-- against a brand-new one.
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects for select
  using (bucket_id = 'avatars');
drop policy if exists "avatars_owner_write" on storage.objects;
create policy "avatars_owner_write" on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars_owner_update" on storage.objects;
create policy "avatars_owner_update" on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars_owner_delete" on storage.objects;
create policy "avatars_owner_delete" on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "project_images_public_read" on storage.objects;
create policy "project_images_public_read" on storage.objects for select
  using (bucket_id = 'project-images');
drop policy if exists "project_images_owner_write" on storage.objects;
create policy "project_images_owner_write" on storage.objects for insert
  with check (bucket_id = 'project-images' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "startup_logos_public_read" on storage.objects;
create policy "startup_logos_public_read" on storage.objects for select
  using (bucket_id = 'startup-logos');
drop policy if exists "startup_logos_owner_write" on storage.objects;
create policy "startup_logos_owner_write" on storage.objects for insert
  with check (bucket_id = 'startup-logos' and (storage.foldername(name))[1] = auth.uid()::text);

-- chat-attachments: private, only conversation members may read/write their own uploads
drop policy if exists "chat_attachments_member_read" on storage.objects;
create policy "chat_attachments_member_read" on storage.objects for select
  using (
    bucket_id = 'chat-attachments'
    and is_conversation_member((storage.foldername(name))[1]::uuid, auth.uid())
  );
drop policy if exists "chat_attachments_member_write" on storage.objects;
create policy "chat_attachments_member_write" on storage.objects for insert
  with check (
    bucket_id = 'chat-attachments'
    and is_conversation_member((storage.foldername(name))[1]::uuid, auth.uid())
  );

drop policy if exists "community_media_public_read" on storage.objects;
create policy "community_media_public_read" on storage.objects for select
  using (bucket_id = 'community-media');
drop policy if exists "community_media_member_write" on storage.objects;
create policy "community_media_member_write" on storage.objects for insert
  with check (bucket_id = 'community-media' and auth.uid() is not null);

-- ============================================================================
-- Skills
-- ============================================================================

insert into skills (name, normalized_name, category) values
  ('Flutter', 'flutter', 'mobile'),
  ('Dart', 'dart', 'language'),
  ('React', 'react', 'frontend'),
  ('Node.js', 'nodejs', 'backend'),
  ('Python', 'python', 'language'),
  ('Machine Learning', 'machine-learning', 'ai'),
  ('Deep Learning', 'deep-learning', 'ai'),
  ('PostgreSQL', 'postgresql', 'database'),
  ('Supabase', 'supabase', 'backend'),
  ('Firebase', 'firebase', 'backend'),
  ('AWS', 'aws', 'cloud'),
  ('Docker', 'docker', 'devops'),
  ('Kubernetes', 'kubernetes', 'devops'),
  ('Go', 'go', 'language'),
  ('Rust', 'rust', 'language'),
  ('Java', 'java', 'language'),
  ('Kotlin', 'kotlin', 'language'),
  ('Swift', 'swift', 'language'),
  ('UI/UX Design', 'ui-ux-design', 'design'),
  ('Product Management', 'product-management', 'business')
on conflict (normalized_name) do nothing;

-- ============================================================================
-- Interests
-- ============================================================================

insert into interests (name, normalized_name) values
  ('AI', 'ai'),
  ('Machine Learning', 'machine-learning'),
  ('Flutter', 'flutter'),
  ('Startups', 'startups'),
  ('Hackathons', 'hackathons'),
  ('Open Source', 'open-source'),
  ('Gaming', 'gaming'),
  ('Movies', 'movies'),
  ('Running', 'running'),
  ('Photography', 'photography'),
  ('Research', 'research'),
  ('Coffee', 'coffee'),
  ('Travel', 'travel'),
  ('Music', 'music'),
  ('Reading', 'reading')
on conflict (normalized_name) do nothing;

-- News is fetched live from a News API (see get-news Edge Function) rather
-- than seeded/ingested into Supabase — nothing to seed here.

-- ============================================================================
-- AI scoring weights (spec section 43 defaults)
-- ============================================================================

insert into ai_scoring_weights (recommendation_type, skills_weight, interests_weight, goals_weight, experience_weight, availability_weight, location_weight, activity_weight)
values
  ('person', 0.35, 0.20, 0.15, 0.10, 0.10, 0.05, 0.05),
  ('hackathon_team', 0.40, 0.15, 0.15, 0.10, 0.15, 0.00, 0.05),
  ('project', 0.40, 0.20, 0.15, 0.10, 0.10, 0.00, 0.05),
  ('job', 0.35, 0.10, 0.15, 0.30, 0.05, 0.05, 0.00),
  ('startup', 0.30, 0.20, 0.20, 0.15, 0.10, 0.00, 0.05),
  ('mentor', 0.30, 0.20, 0.20, 0.15, 0.10, 0.00, 0.05),
  ('local_person', 0.05, 0.35, 0.10, 0.00, 0.25, 0.20, 0.05),
  ('news', 0.10, 0.50, 0.10, 0.00, 0.00, 0.00, 0.30)
on conflict (recommendation_type) do nothing;

-- ============================================================================
-- Demo communities / hackathons / jobs
-- NOTE: these reference no real users; they use a fixed demo UUID that only
-- resolves once a matching auth user exists locally. Safe no-op in a fresh
-- database until you create a local dev user with this id.
-- ============================================================================

do $$
declare
  demo_user uuid := '00000000-0000-0000-0000-000000000001';
begin
  if exists (select 1 from auth.users where id = demo_user) then
    insert into profiles (id, username, full_name, primary_user_type, profile_completed)
    values (demo_user, 'demo_user', 'Demo User', 'developer', true)
    on conflict (id) do nothing;

    insert into communities (owner_id, name, slug, description, community_type)
    values (demo_user, 'Flutter Developers', 'flutter-developers', 'A community for Flutter builders.', 'technology')
    on conflict (slug) do nothing;

    insert into hackathons (name, event_date, created_by)
    values ('Demo Hackathon 2026', current_date + interval '14 days', demo_user)
    on conflict ((lower(name))) do nothing;

    insert into jobs (poster_id, company_name, title, description, employment_type, work_mode)
    values (demo_user, 'Demo Company', 'Flutter Developer', 'Sample job listing for local development.', 'full_time', 'remote')
    on conflict do nothing;
  end if;
end $$;

-- ============================================================================
-- Referrals / Mock Interviews / Intent System demo data
-- Needs a SECOND demo user so the two-party flows (a referral request, an
-- interview-practice pairing, an intent match) have someone on the other
-- side. Same safe no-op pattern as above: only runs once both demo auth
-- users exist locally.
-- ============================================================================

do $$
declare
  demo_user uuid := '00000000-0000-0000-0000-000000000001';
  demo_user_2 uuid := '00000000-0000-0000-0000-000000000002';
  flutter_skill uuid;
  ml_skill uuid;
  python_skill uuid;
  ai_interest uuid;
  startups_interest uuid;
  demo_offer_id uuid;
  demo_intent_id uuid;
begin
  if exists (select 1 from auth.users where id = demo_user)
     and exists (select 1 from auth.users where id = demo_user_2) then

    insert into profiles (id, username, full_name, primary_user_type, current_company, current_role, profile_completed)
    values (demo_user_2, 'demo_user_2', 'Ava Kapoor', 'developer', 'Nova AI', 'ML Engineer', true)
    on conflict (id) do nothing;

    select id into flutter_skill from skills where normalized_name = 'flutter';
    select id into ml_skill from skills where normalized_name = 'machine-learning';
    select id into python_skill from skills where normalized_name = 'python';
    select id into ai_interest from interests where normalized_name = 'ai';
    select id into startups_interest from interests where normalized_name = 'startups';

    insert into profile_skills (profile_id, skill_id, experience_level) values
      (demo_user, flutter_skill, 'advanced'),
      (demo_user_2, ml_skill, 'expert'),
      (demo_user_2, python_skill, 'advanced')
    on conflict (profile_id, skill_id) do nothing;

    insert into profile_interests (profile_id, interest_id) values
      (demo_user, ai_interest),
      (demo_user_2, ai_interest),
      (demo_user_2, startups_interest)
    on conflict (profile_id, interest_id) do nothing;

    -- Referral Marketplace: demo_user offers a referral, Ava requests one
    -- and has already submitted her resume.
    insert into referral_offers (profile_id, company_name, role_title, notes)
    values (demo_user, 'Demo Company', 'Software Engineer', 'Happy to refer for backend or mobile roles.')
    on conflict (profile_id, company_name) do nothing
    returning id into demo_offer_id;

    if demo_offer_id is null then
      select id into demo_offer_id from referral_offers
      where profile_id = demo_user and company_name = 'Demo Company';
    end if;

    insert into referral_requests (offer_id, referrer_id, requester_id, job_title, message, resume_url, status)
    select demo_offer_id, demo_user, demo_user_2, 'Backend Engineer',
      'Would love a referral for the backend role.', 'https://example.com/resume-ava.pdf', 'resume_submitted'
    where not exists (
      select 1 from referral_requests where offer_id = demo_offer_id and requester_id = demo_user_2
    );

    -- Mock Interview Matching: Ava is in the practice pool, demo_user has an
    -- already-accepted pairing with her.
    insert into interview_practice_profiles (profile_id, target_role, topics, experience_level, availability_notes)
    values (demo_user_2, 'ML Engineer', array['System Design', 'Machine Learning'], 'advanced', 'Weekday evenings, IST')
    on conflict (profile_id) do nothing;

    insert into interview_practice_requests (requester_id, partner_id, target_role, message, status)
    select demo_user, demo_user_2, 'ML Engineer', 'Would love to practice system design with you.', 'accepted'
    where not exists (
      select 1 from interview_practice_requests where requester_id = demo_user and partner_id = demo_user_2
    );

    -- Structured availability, used by the Intent matching engine's
    -- compatibility check (both free Saturday late morning).
    insert into user_availability (profile_id, day_of_week, start_time, end_time)
    select demo_user, 6, '10:00', '14:00'
    where not exists (select 1 from user_availability where profile_id = demo_user);

    insert into user_availability (profile_id, day_of_week, start_time, end_time)
    select demo_user_2, 6, '11:00', '15:00'
    where not exists (select 1 from user_availability where profile_id = demo_user_2);

    -- Intent System: demo_user is looking for hackathon teammates with ML
    -- skills, offering Flutter in return.
    insert into intents (
      profile_id, intent_type, title, description, experience_level,
      preferred_role, work_mode, commitment_level, visibility, expires_at
    )
    select
      demo_user, 'find_hackathon_teammates', 'Need an ML engineer for an AI hackathon',
      'Building an AI-powered demo for an upcoming hackathon — looking for someone strong in ML to pair with.',
      'intermediate', 'ML Engineer', 'remote', 'Weekends', 'public', now() + interval '14 days'
    where not exists (
      select 1 from intents where profile_id = demo_user and title = 'Need an ML engineer for an AI hackathon'
    )
    returning id into demo_intent_id;

    if demo_intent_id is null then
      select id into demo_intent_id from intents
      where profile_id = demo_user and title = 'Need an ML engineer for an AI hackathon';
    end if;

    insert into intent_skills (intent_id, skill_id, direction) values
      (demo_intent_id, ml_skill, 'needed'),
      (demo_intent_id, flutter_skill, 'offered')
    on conflict do nothing;

    -- Pre-computed match so the Intent Matches screen has something to show
    -- immediately, without needing ai-match-intent deployed/invoked locally.
    insert into intent_matches (
      intent_id, candidate_id, score, matched_skills, missing_skills,
      complementary_skills, shared_interests, availability_compatible, reasons, model_version
    )
    values (
      demo_intent_id, demo_user_2, 92,
      array['Machine Learning'], array[]::text[], array['Python'], array['AI'], true,
      array[
        'They have the skills you need: Machine Learning',
        'They also bring: Python',
        'Shared interest in AI',
        'Available at compatible times'
      ],
      'seed-demo'
    )
    on conflict (intent_id, candidate_id) do nothing;
  end if;
end $$;
