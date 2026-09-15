-- 0002_enums.sql
-- Central enum/type definitions used across the schema.

create type user_type as enum (
  'student', 'developer', 'professional', 'job_seeker',
  'founder', 'researcher', 'other'
);

create type employment_type as enum (
  'full_time', 'part_time', 'internship', 'contract', 'freelance', 'other'
);

create type job_employment_type as enum (
  'full_time', 'internship', 'freelance', 'contract', 'part_time', 'research', 'volunteer'
);

create type work_mode as enum ('remote', 'hybrid', 'onsite');

create type experience_level as enum ('beginner', 'intermediate', 'advanced', 'expert');

create type proof_type as enum (
  'github', 'leetcode', 'kaggle', 'huggingface', 'portfolio', 'certification', 'project'
);

create type connection_status as enum (
  'pending', 'accepted', 'declined', 'cancelled', 'blocked'
);

create type conversation_type as enum ('direct');

create type message_type as enum ('text', 'image', 'file', 'system');

create type hackathon_mode as enum ('online', 'offline', 'hybrid');

create type participant_status as enum ('registered', 'confirmed', 'withdrawn');

create type team_requirement_status as enum ('open', 'full', 'closed');

create type invitation_status as enum ('pending', 'accepted', 'rejected', 'cancelled');

create type collaboration_type as enum (
  'personal', 'startup', 'open_source', 'research', 'hackathon', 'other'
);

create type compensation_type as enum ('paid', 'unpaid', 'equity', 'negotiable');

create type project_status as enum ('open', 'in_progress', 'completed', 'closed');

create type project_interest_status as enum ('pending', 'accepted', 'rejected');

create type job_status as enum ('open', 'closed', 'filled');

create type job_application_status as enum (
  'submitted', 'reviewing', 'shortlisted', 'rejected', 'accepted', 'withdrawn'
);

create type startup_stage as enum ('idea', 'mvp', 'early_revenue', 'growth', 'funded');

create type opportunity_status as enum ('open', 'closed', 'filled');

create type pricing_type as enum ('free', 'paid');

create type mentor_request_status as enum ('pending', 'accepted', 'declined', 'cancelled', 'completed');

create type mentor_session_status as enum ('scheduled', 'completed', 'cancelled', 'no_show');

create type meetup_status as enum ('pending', 'accepted', 'declined', 'cancelled', 'completed');

create type community_role as enum ('member', 'moderator', 'admin');

create type community_type as enum (
  'technology', 'city', 'student', 'startup', 'research', 'open_source', 'interest_based'
);

create type event_type as enum (
  'hackathon', 'workshop', 'conference', 'tech_talk', 'study_session', 'community_event'
);

create type recommendation_type as enum (
  'person', 'hackathon_team', 'project', 'job', 'startup', 'mentor', 'local_person', 'news'
);

create type report_category as enum (
  'spam', 'harassment', 'fake_profile', 'scam', 'inappropriate_content', 'unsafe_behavior', 'fraud', 'other'
);

create type report_target_type as enum (
  'profile', 'message', 'job', 'project', 'hackathon', 'community', 'startup', 'event'
);

create type report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');

create type app_role as enum ('user', 'admin', 'moderator');
