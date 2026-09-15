/// Privacy-conscious analytics event names (spec section 75). Payloads must
/// stay minimal — ids needed to understand the action, never message
/// content, exact location, or other unnecessary personal data.
class AnalyticsEvents {
  AnalyticsEvents._();

  static const profileCompleted = 'profile_completed';
  static const connectionSent = 'connection_sent';
  static const connectionAccepted = 'connection_accepted';
  static const messageSent = 'message_sent';
  static const hackathonViewed = 'hackathon_viewed';
  static const teamRequest = 'team_request';
  static const projectInterest = 'project_interest';
  static const jobApplication = 'job_application';
  static const mentorRequest = 'mentor_request';
  static const localConnectionRequest = 'local_connection_request';
  static const meetupSuggested = 'meetup_suggested';
  static const meetupAccepted = 'meetup_accepted';
  static const newsOpened = 'news_opened';
  static const referralRequested = 'referral_requested';
  static const interviewPracticeRequested = 'interview_practice_requested';
}
