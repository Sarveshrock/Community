/// App-wide constants that aren't environment secrets.
class AppConstants {
  AppConstants._();

  static const String appName = 'Communeo';

  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  static const int messageDebounceMs = 300;
  static const int searchDebounceMs = 400;

  static const double maxContentWidth = 720;
  static const double tabletBreakpoint = 700;
  static const double desktopBreakpoint = 1100;
}

/// Supabase storage bucket names (spec section 48).
class StorageBuckets {
  StorageBuckets._();

  static const String avatars = 'avatars';
  static const String projectImages = 'project-images';
  static const String startupLogos = 'startup-logos';
  static const String chatAttachments = 'chat-attachments';
  static const String communityMedia = 'community-media';
  static const String postMedia = 'post-media';
  static const String resumes = 'resumes';
}

/// Supabase Postgres table names, kept centralized to avoid typos scattered
/// across data sources.
class Tables {
  Tables._();

  static const String profiles = 'profiles';
  static const String userRoles = 'user_roles';
  static const String experiences = 'experiences';
  static const String education = 'education';
  static const String skills = 'skills';
  static const String profileSkills = 'profile_skills';
  static const String interests = 'interests';
  static const String profileInterests = 'profile_interests';
  static const String optionalProofs = 'optional_proofs';
  static const String connections = 'connections';
  static const String connectionNicknames = 'connection_nicknames';
  static const String blocks = 'blocks';
  static const String conversations = 'conversations';
  static const String conversationMembers = 'conversation_members';
  static const String messages = 'messages';
  static const String messageReactions = 'message_reactions';
  static const String hackathons = 'hackathons';
  static const String hackathonTeamRequirements = 'hackathon_team_requirements';
  static const String hackathonTeamMembers = 'hackathon_team_members';
  static const String hackathonTeamJoinRequests =
      'hackathon_team_join_requests';
  static const String teamInvitations = 'team_invitations';
  static const String hackathonTeamRequiredSkills =
      'hackathon_team_required_skills';
  static const String hackathonTeamRoleRequirements =
      'hackathon_team_role_requirements';
  static const String hackathonTeamRoleRequiredSkills =
      'hackathon_team_role_required_skills';
  static const String hackathonTeamSkillsHave = 'hackathon_team_skills_have';
  static const String projects = 'projects';
  static const String projectRequirements = 'project_requirements';
  static const String projectRequiredSkills = 'project_required_skills';
  static const String projectInterests = 'project_interests';
  static const String jobs = 'jobs';
  static const String jobApplications = 'job_applications';
  static const String jobRequiredSkills = 'job_required_skills';
  static const String jobPreferredSkills = 'job_preferred_skills';
  static const String jobApplicationQuestions = 'job_application_questions';
  static const String jobApplicationAnswers = 'job_application_answers';
  static const String startups = 'startups';
  static const String startupMembers = 'startup_members';
  static const String startupOpportunities = 'startup_opportunities';
  static const String mentorProfiles = 'mentor_profiles';
  static const String mentorRequests = 'mentor_requests';
  static const String mentorSessions = 'mentor_sessions';
  static const String localProfiles = 'local_profiles';
  static const String localPreferences = 'local_preferences';
  static const String localConnections = 'local_connections';
  static const String meetupSuggestions = 'meetup_suggestions';
  static const String communities = 'communities';
  static const String communityMembers = 'community_members';
  static const String communityPosts = 'community_posts';
  static const String communityComments = 'community_comments';
  static const String communityTopics = 'community_topics';
  static const String communityJoinRequests = 'community_join_requests';
  static const String communityQuestions = 'community_questions';
  static const String communityAnswers = 'community_answers';
  static const String events = 'events';
  static const String eventAttendees = 'event_attendees';
  static const String eventPrivateDetails = 'event_private_details';
  static const String eventTags = 'event_tags';
  static const String eventAgendaItems = 'event_agenda_items';
  static const String eventSpeakers = 'event_speakers';
  static const String eventJoinRequests = 'event_join_requests';
  static const String newsItems = 'news_items';
  static const String savedNews = 'saved_news';
  static const String hiddenNews = 'hidden_news';
  static const String newsComments = 'news_comments';
  static const String notifications = 'notifications';
  static const String deviceTokens = 'device_tokens';
  static const String notificationPreferences = 'notification_preferences';
  static const String aiRecommendations = 'ai_recommendations';
  static const String reports = 'reports';
  static const String moderationActions = 'moderation_actions';
  static const String analyticsEvents = 'analytics_events';
  static const String posts = 'posts';
  static const String postMedia = 'post_media';
  static const String postLinks = 'post_links';
  static const String postMentions = 'post_mentions';
  static const String postLikes = 'post_likes';
  static const String postComments = 'post_comments';
  static const String referralOffers = 'referral_offers';
  static const String referralRequests = 'referral_requests';
  static const String interviewPracticeProfiles = 'interview_practice_profiles';
  static const String interviewPracticeRequests = 'interview_practice_requests';
  static const String intents = 'intents';
  static const String intentSkills = 'intent_skills';
  static const String userAvailability = 'user_availability';
  static const String intentMatches = 'intent_matches';
  static const String intentRecommendations = 'intent_recommendations';
}
