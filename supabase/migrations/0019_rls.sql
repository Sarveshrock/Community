-- 0019_rls.sql
-- Row Level Security for every user-data table.

-- ============================================================================
-- Helper functions
-- ============================================================================

create or replace function is_admin(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from user_roles where profile_id = uid and role in ('admin', 'moderator')
  );
$$;

create or replace function is_connection_accepted(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from connections
    where status = 'accepted'
      and ((requester_id = a and receiver_id = b) or (requester_id = b and receiver_id = a))
  );
$$;

create or replace function is_conversation_member(conv uuid, uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from conversation_members where conversation_id = conv and profile_id = uid
  );
$$;

create or replace function is_community_member(comm uuid, uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from community_members where community_id = comm and profile_id = uid
  );
$$;

create or replace function is_startup_member(s uuid, uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from startup_members where startup_id = s and profile_id = uid
  );
$$;

-- ============================================================================
-- Enable RLS everywhere
-- ============================================================================

alter table profiles enable row level security;
alter table user_roles enable row level security;
alter table experiences enable row level security;
alter table education enable row level security;
alter table skills enable row level security;
alter table profile_skills enable row level security;
alter table interests enable row level security;
alter table profile_interests enable row level security;
alter table optional_proofs enable row level security;
alter table connections enable row level security;
alter table blocks enable row level security;
alter table conversations enable row level security;
alter table conversation_members enable row level security;
alter table messages enable row level security;
alter table message_reactions enable row level security;
alter table hackathons enable row level security;
alter table hackathon_participants enable row level security;
alter table hackathon_team_requirements enable row level security;
alter table hackathon_team_required_skills enable row level security;
alter table team_invitations enable row level security;
alter table projects enable row level security;
alter table project_requirements enable row level security;
alter table project_required_skills enable row level security;
alter table project_interests enable row level security;
alter table jobs enable row level security;
alter table job_required_skills enable row level security;
alter table job_applications enable row level security;
alter table startups enable row level security;
alter table startup_members enable row level security;
alter table startup_opportunities enable row level security;
alter table mentor_profiles enable row level security;
alter table mentor_requests enable row level security;
alter table mentor_sessions enable row level security;
alter table local_profiles enable row level security;
alter table local_preferences enable row level security;
alter table local_connections enable row level security;
alter table meetup_suggestions enable row level security;
alter table communities enable row level security;
alter table community_members enable row level security;
alter table community_posts enable row level security;
alter table community_comments enable row level security;
alter table events enable row level security;
alter table event_attendees enable row level security;
alter table news_sources enable row level security;
alter table news_categories enable row level security;
alter table news_items enable row level security;
alter table news_item_categories enable row level security;
alter table saved_news enable row level security;
alter table hidden_news enable row level security;
alter table notifications enable row level security;
alter table device_tokens enable row level security;
alter table notification_preferences enable row level security;
alter table ai_recommendations enable row level security;
alter table ai_match_scores enable row level security;
alter table ai_feedback enable row level security;
alter table ai_scoring_weights enable row level security;
alter table reports enable row level security;
alter table moderation_actions enable row level security;

-- ============================================================================
-- Profiles
-- ============================================================================

create policy profiles_select_discoverable on profiles for select
  using (
    id = auth.uid()
    or professional_discoverable = true
    or is_admin(auth.uid())
  );

create policy profiles_insert_self on profiles for insert
  with check (id = auth.uid());

create policy profiles_update_self on profiles for update
  using (id = auth.uid() or is_admin(auth.uid()))
  with check (id = auth.uid() or is_admin(auth.uid()));

create policy user_roles_select_self on user_roles for select
  using (profile_id = auth.uid() or is_admin(auth.uid()));

-- user_roles has no client insert/update/delete policy: role grants are
-- server-side only (service_role / SQL), never trusted from client input.

-- ============================================================================
-- Experience / education / skills / interests / proofs
-- ============================================================================

create policy experiences_select on experiences for select
  using (exists (select 1 from profiles p where p.id = profile_id and (p.id = auth.uid() or p.professional_discoverable)));
create policy experiences_write on experiences for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy education_select on education for select
  using (exists (select 1 from profiles p where p.id = profile_id and (p.id = auth.uid() or p.professional_discoverable)));
create policy education_write on education for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy skills_select_all on skills for select using (true);
create policy interests_select_all on interests for select using (true);

create policy profile_skills_select on profile_skills for select
  using (exists (select 1 from profiles p where p.id = profile_id and (p.id = auth.uid() or p.professional_discoverable)));
create policy profile_skills_write on profile_skills for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy profile_interests_select on profile_interests for select
  using (exists (select 1 from profiles p where p.id = profile_id and (p.id = auth.uid() or p.professional_discoverable)));
create policy profile_interests_write on profile_interests for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy optional_proofs_select on optional_proofs for select
  using (exists (select 1 from profiles p where p.id = profile_id and (p.id = auth.uid() or p.professional_discoverable)));
create policy optional_proofs_write on optional_proofs for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- ============================================================================
-- Connections / blocks
-- ============================================================================

create policy connections_select on connections for select
  using (requester_id = auth.uid() or receiver_id = auth.uid());
create policy connections_insert on connections for insert
  with check (
    requester_id = auth.uid()
    and receiver_id <> auth.uid()
    and not is_blocked(auth.uid(), receiver_id)
  );
create policy connections_update on connections for update
  using (requester_id = auth.uid() or receiver_id = auth.uid())
  with check (requester_id = auth.uid() or receiver_id = auth.uid());

create policy blocks_select on blocks for select
  using (blocker_id = auth.uid());
create policy blocks_insert on blocks for insert
  with check (blocker_id = auth.uid());
create policy blocks_delete on blocks for delete
  using (blocker_id = auth.uid());

-- ============================================================================
-- Messaging
-- ============================================================================

create policy conversations_select on conversations for select
  using (is_conversation_member(id, auth.uid()));
-- Conversations are created only via get_or_create_direct_conversation()
-- (SECURITY DEFINER), never directly by clients.

create policy conversation_members_select on conversation_members for select
  using (is_conversation_member(conversation_id, auth.uid()));
create policy conversation_members_update_self on conversation_members for update
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy messages_select on messages for select
  using (is_conversation_member(conversation_id, auth.uid()));
create policy messages_insert on messages for insert
  with check (
    sender_id = auth.uid()
    and is_conversation_member(conversation_id, auth.uid())
  );
create policy messages_update_own on messages for update
  using (sender_id = auth.uid()) with check (sender_id = auth.uid());

create policy message_reactions_select on message_reactions for select
  using (exists (select 1 from messages m where m.id = message_id and is_conversation_member(m.conversation_id, auth.uid())));
create policy message_reactions_write on message_reactions for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- ============================================================================
-- Hackathons
-- ============================================================================

create policy hackathons_select_all on hackathons for select using (true);
create policy hackathons_insert on hackathons for insert with check (host_id = auth.uid());
create policy hackathons_update on hackathons for update
  using (host_id = auth.uid() or is_admin(auth.uid()))
  with check (host_id = auth.uid() or is_admin(auth.uid()));
create policy hackathons_delete on hackathons for delete
  using (host_id = auth.uid() or is_admin(auth.uid()));

create policy hackathon_participants_select on hackathon_participants for select using (true);
create policy hackathon_participants_write on hackathon_participants for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy hackathon_team_requirements_select_all on hackathon_team_requirements for select using (true);
create policy hackathon_team_requirements_insert on hackathon_team_requirements for insert
  with check (creator_id = auth.uid());
create policy hackathon_team_requirements_update on hackathon_team_requirements for update
  using (creator_id = auth.uid() or is_admin(auth.uid()))
  with check (creator_id = auth.uid() or is_admin(auth.uid()));
create policy hackathon_team_requirements_delete on hackathon_team_requirements for delete
  using (creator_id = auth.uid() or is_admin(auth.uid()));

create policy hackathon_team_required_skills_select on hackathon_team_required_skills for select using (true);
create policy hackathon_team_required_skills_write on hackathon_team_required_skills for all
  using (exists (select 1 from hackathon_team_requirements r where r.id = team_requirement_id and r.creator_id = auth.uid()))
  with check (exists (select 1 from hackathon_team_requirements r where r.id = team_requirement_id and r.creator_id = auth.uid()));

create policy team_invitations_select on team_invitations for select
  using (sender_id = auth.uid() or receiver_id = auth.uid());
create policy team_invitations_insert on team_invitations for insert
  with check (sender_id = auth.uid() and not is_blocked(auth.uid(), receiver_id));
create policy team_invitations_update on team_invitations for update
  using (sender_id = auth.uid() or receiver_id = auth.uid())
  with check (sender_id = auth.uid() or receiver_id = auth.uid());

-- ============================================================================
-- Projects
-- ============================================================================

create policy projects_select_all on projects for select using (true);
create policy projects_insert on projects for insert with check (owner_id = auth.uid());
create policy projects_update on projects for update
  using (owner_id = auth.uid() or is_admin(auth.uid()))
  with check (owner_id = auth.uid() or is_admin(auth.uid()));
create policy projects_delete on projects for delete
  using (owner_id = auth.uid() or is_admin(auth.uid()));

create policy project_requirements_select on project_requirements for select using (true);
create policy project_requirements_write on project_requirements for all
  using (exists (select 1 from projects p where p.id = project_id and p.owner_id = auth.uid()))
  with check (exists (select 1 from projects p where p.id = project_id and p.owner_id = auth.uid()));

create policy project_required_skills_select on project_required_skills for select using (true);
create policy project_required_skills_write on project_required_skills for all
  using (exists (select 1 from projects p where p.id = project_id and p.owner_id = auth.uid()))
  with check (exists (select 1 from projects p where p.id = project_id and p.owner_id = auth.uid()));

create policy project_interests_select on project_interests for select
  using (
    profile_id = auth.uid()
    or exists (select 1 from projects p where p.id = project_id and p.owner_id = auth.uid())
  );
create policy project_interests_insert on project_interests for insert
  with check (profile_id = auth.uid());
create policy project_interests_update on project_interests for update
  using (
    profile_id = auth.uid()
    or exists (select 1 from projects p where p.id = project_id and p.owner_id = auth.uid())
  )
  with check (
    profile_id = auth.uid()
    or exists (select 1 from projects p where p.id = project_id and p.owner_id = auth.uid())
  );

-- ============================================================================
-- Jobs
-- ============================================================================

create policy jobs_select_all on jobs for select using (true);
create policy jobs_insert on jobs for insert with check (poster_id = auth.uid());
create policy jobs_update on jobs for update
  using (poster_id = auth.uid() or is_admin(auth.uid()))
  with check (poster_id = auth.uid() or is_admin(auth.uid()));
create policy jobs_delete on jobs for delete
  using (poster_id = auth.uid() or is_admin(auth.uid()));

create policy job_required_skills_select on job_required_skills for select using (true);
create policy job_required_skills_write on job_required_skills for all
  using (exists (select 1 from jobs j where j.id = job_id and j.poster_id = auth.uid()))
  with check (exists (select 1 from jobs j where j.id = job_id and j.poster_id = auth.uid()));

create policy job_applications_select on job_applications for select
  using (
    profile_id = auth.uid()
    or exists (select 1 from jobs j where j.id = job_id and j.poster_id = auth.uid())
  );
create policy job_applications_insert on job_applications for insert
  with check (profile_id = auth.uid());
create policy job_applications_update on job_applications for update
  using (
    profile_id = auth.uid()
    or exists (select 1 from jobs j where j.id = job_id and j.poster_id = auth.uid())
  )
  with check (
    profile_id = auth.uid()
    or exists (select 1 from jobs j where j.id = job_id and j.poster_id = auth.uid())
  );

-- ============================================================================
-- Startups
-- ============================================================================

create policy startups_select_all on startups for select using (true);
create policy startups_insert on startups for insert with check (owner_id = auth.uid());
create policy startups_update on startups for update
  using (owner_id = auth.uid() or is_startup_member(id, auth.uid()) or is_admin(auth.uid()))
  with check (owner_id = auth.uid() or is_startup_member(id, auth.uid()) or is_admin(auth.uid()));
create policy startups_delete on startups for delete
  using (owner_id = auth.uid() or is_admin(auth.uid()));

create policy startup_members_select on startup_members for select using (true);
create policy startup_members_write on startup_members for all
  using (exists (select 1 from startups s where s.id = startup_id and s.owner_id = auth.uid()))
  with check (exists (select 1 from startups s where s.id = startup_id and s.owner_id = auth.uid()));

create policy startup_opportunities_select_all on startup_opportunities for select using (true);
create policy startup_opportunities_write on startup_opportunities for all
  using (exists (select 1 from startups s where s.id = startup_id and (s.owner_id = auth.uid() or is_startup_member(s.id, auth.uid()))))
  with check (exists (select 1 from startups s where s.id = startup_id and (s.owner_id = auth.uid() or is_startup_member(s.id, auth.uid()))));

-- ============================================================================
-- Mentorship
-- ============================================================================

create policy mentor_profiles_select_all on mentor_profiles for select using (true);
create policy mentor_profiles_write on mentor_profiles for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy mentor_requests_select on mentor_requests for select
  using (mentor_id = auth.uid() or requester_id = auth.uid());
create policy mentor_requests_insert on mentor_requests for insert
  with check (requester_id = auth.uid() and not is_blocked(auth.uid(), mentor_id));
create policy mentor_requests_update on mentor_requests for update
  using (mentor_id = auth.uid() or requester_id = auth.uid())
  with check (mentor_id = auth.uid() or requester_id = auth.uid());

create policy mentor_sessions_select on mentor_sessions for select
  using (exists (
    select 1 from mentor_requests r where r.id = mentor_request_id
    and (r.mentor_id = auth.uid() or r.requester_id = auth.uid())
  ));
create policy mentor_sessions_write on mentor_sessions for all
  using (exists (
    select 1 from mentor_requests r where r.id = mentor_request_id
    and (r.mentor_id = auth.uid() or r.requester_id = auth.uid())
  ))
  with check (exists (
    select 1 from mentor_requests r where r.id = mentor_request_id
    and (r.mentor_id = auth.uid() or r.requester_id = auth.uid())
  ));

-- ============================================================================
-- Local (privacy sensitive — no direct location exposure)
-- ============================================================================

create policy local_profiles_select_self on local_profiles for select
  using (profile_id = auth.uid() or is_admin(auth.uid()));
create policy local_profiles_write on local_profiles for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy local_preferences_select_self on local_preferences for select
  using (profile_id = auth.uid());
create policy local_preferences_write on local_preferences for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy local_connections_select on local_connections for select
  using (requester_id = auth.uid() or receiver_id = auth.uid());
create policy local_connections_insert on local_connections for insert
  with check (
    requester_id = auth.uid()
    and receiver_id <> auth.uid()
    and not is_blocked(auth.uid(), receiver_id)
  );
create policy local_connections_update on local_connections for update
  using (requester_id = auth.uid() or receiver_id = auth.uid())
  with check (requester_id = auth.uid() or receiver_id = auth.uid());

create policy meetup_suggestions_select on meetup_suggestions for select
  using (exists (
    select 1 from local_connections lc where lc.id = local_connection_id
    and (lc.requester_id = auth.uid() or lc.receiver_id = auth.uid())
  ));
create policy meetup_suggestions_insert on meetup_suggestions for insert
  with check (
    suggested_by = auth.uid()
    and exists (
      select 1 from local_connections lc where lc.id = local_connection_id
      and (lc.requester_id = auth.uid() or lc.receiver_id = auth.uid())
    )
  );
create policy meetup_suggestions_update on meetup_suggestions for update
  using (exists (
    select 1 from local_connections lc where lc.id = local_connection_id
    and (lc.requester_id = auth.uid() or lc.receiver_id = auth.uid())
  ))
  with check (exists (
    select 1 from local_connections lc where lc.id = local_connection_id
    and (lc.requester_id = auth.uid() or lc.receiver_id = auth.uid())
  ));

-- Note: exact location is never in a client-selectable table/policy.
-- Local discovery must go through get_local_candidates() (see 0020), which
-- returns only distance buckets, never coordinates.

-- ============================================================================
-- Communities / events
-- ============================================================================

create policy communities_select on communities for select
  using (is_private = false or is_community_member(id, auth.uid()) or owner_id = auth.uid());
create policy communities_insert on communities for insert with check (owner_id = auth.uid());
create policy communities_update on communities for update
  using (owner_id = auth.uid() or is_admin(auth.uid()))
  with check (owner_id = auth.uid() or is_admin(auth.uid()));
create policy communities_delete on communities for delete
  using (owner_id = auth.uid() or is_admin(auth.uid()));

create policy community_members_select on community_members for select
  using (
    profile_id = auth.uid()
    or exists (select 1 from communities c where c.id = community_id and (c.is_private = false or c.owner_id = auth.uid()))
  );
create policy community_members_insert on community_members for insert
  with check (profile_id = auth.uid());
create policy community_members_delete on community_members for delete
  using (profile_id = auth.uid() or exists (select 1 from communities c where c.id = community_id and c.owner_id = auth.uid()));

create policy community_posts_select on community_posts for select
  using (exists (select 1 from communities c where c.id = community_id and (c.is_private = false or is_community_member(c.id, auth.uid()))));
create policy community_posts_insert on community_posts for insert
  with check (author_id = auth.uid() and is_community_member(community_id, auth.uid()));
create policy community_posts_update on community_posts for update
  using (author_id = auth.uid() or is_admin(auth.uid()))
  with check (author_id = auth.uid() or is_admin(auth.uid()));

create policy community_comments_select on community_comments for select
  using (exists (
    select 1 from community_posts p join communities c on c.id = p.community_id
    where p.id = post_id and (c.is_private = false or is_community_member(c.id, auth.uid()))
  ));
create policy community_comments_insert on community_comments for insert
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from community_posts p where p.id = post_id and is_community_member(p.community_id, auth.uid())
    )
  );
create policy community_comments_update on community_comments for update
  using (author_id = auth.uid() or is_admin(auth.uid()))
  with check (author_id = auth.uid() or is_admin(auth.uid()));

create policy events_select_all on events for select using (true);
create policy events_insert on events for insert with check (host_id = auth.uid());
create policy events_update on events for update
  using (host_id = auth.uid() or is_admin(auth.uid()))
  with check (host_id = auth.uid() or is_admin(auth.uid()));
create policy events_delete on events for delete
  using (host_id = auth.uid() or is_admin(auth.uid()));

create policy event_attendees_select on event_attendees for select using (true);
create policy event_attendees_write on event_attendees for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- ============================================================================
-- News (server-populated, client read-only + personal save/hide state)
-- ============================================================================

create policy news_sources_select_all on news_sources for select using (true);
create policy news_categories_select_all on news_categories for select using (true);
create policy news_items_select_all on news_items for select using (true);
create policy news_item_categories_select_all on news_item_categories for select using (true);
-- No client insert/update/delete policies on news_* tables: ingestion is
-- performed only by Edge Functions using the service role key.

create policy saved_news_select on saved_news for select using (profile_id = auth.uid());
create policy saved_news_write on saved_news for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy hidden_news_select on hidden_news for select using (profile_id = auth.uid());
create policy hidden_news_write on hidden_news for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- ============================================================================
-- Notifications
-- ============================================================================

create policy notifications_select on notifications for select using (profile_id = auth.uid());
create policy notifications_update on notifications for update
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
-- No client insert policy: notifications are created only by Edge Functions
-- / SECURITY DEFINER functions using the service role.

create policy device_tokens_select on device_tokens for select using (profile_id = auth.uid());
create policy device_tokens_write on device_tokens for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy notification_preferences_select on notification_preferences for select using (profile_id = auth.uid());
create policy notification_preferences_write on notification_preferences for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- ============================================================================
-- AI
-- ============================================================================

create policy ai_recommendations_select on ai_recommendations for select using (profile_id = auth.uid());
-- No client write policies: recommendations are computed server-side only.

create policy ai_match_scores_select on ai_match_scores for select using (profile_id = auth.uid());

create policy ai_feedback_select on ai_feedback for select using (profile_id = auth.uid());
create policy ai_feedback_insert on ai_feedback for insert with check (profile_id = auth.uid());

create policy ai_scoring_weights_select_all on ai_scoring_weights for select using (true);
create policy ai_scoring_weights_admin_write on ai_scoring_weights for all
  using (is_admin(auth.uid())) with check (is_admin(auth.uid()));

-- ============================================================================
-- Reports / moderation
-- ============================================================================

create policy reports_select on reports for select
  using (reporter_id = auth.uid() or is_admin(auth.uid()));
create policy reports_insert on reports for insert with check (reporter_id = auth.uid());
create policy reports_update_admin on reports for update
  using (is_admin(auth.uid())) with check (is_admin(auth.uid()));

create policy moderation_actions_select_admin on moderation_actions for select
  using (is_admin(auth.uid()));
create policy moderation_actions_insert_admin on moderation_actions for insert
  with check (is_admin(auth.uid()) and moderator_id = auth.uid());
