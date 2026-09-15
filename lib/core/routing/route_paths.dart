part of 'app_router.dart';

class RoutePaths {
  RoutePaths._();

  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const onboarding = '/onboarding';

  static const home = '/home';
  static const discover = '/discover';
  static const create = '/create';
  static const messages = '/messages';
  static const profile = '/profile';

  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const appIconSettings = '/settings/app-icon';
  static const profilePhotoPrivacy = '/settings/profile-photo';
  static const notifications = '/notifications';
  static const search = '/search';
  static const connections = '/connections';
  static const buddies = '/buddies';
  static const blockedUsers = '/connections/blocked';

  static const chat = '/chat/:id';
  static String chatOf(String id) => '/chat/$id';

  static const people = '/people';
  static const personDetail = '/people/:id';
  static String personDetailOf(String id) => '/people/$id';

  static const hackathons = '/hackathons';
  static const newTeamRequirementStandalone = '/hackathons/teams/new';
  static const hackathonDetail = '/hackathons/:id';
  static String hackathonDetailOf(String id) => '/hackathons/$id';
  static const newTeamRequirement = '/hackathons/:id/teams/new';
  static String newTeamRequirementOf(String id) => '/hackathons/$id/teams/new';
  static const teamDetail = '/teams/:id';
  static String teamDetailOf(String id) => '/teams/$id';
  static const editTeamRequirement = '/teams/:id/edit';
  static String editTeamRequirementOf(String id) => '/teams/$id/edit';
  static const teamChat = '/teams/:id/chat';
  static String teamChatOf(String id) => '/teams/$id/chat';

  static const projects = '/projects';
  static const newProject = '/projects/new';
  static const projectDetail = '/projects/:id';
  static String projectDetailOf(String id) => '/projects/$id';

  static const jobs = '/jobs';
  static const newJob = '/jobs/new';
  static const jobDetail = '/jobs/:id';
  static String jobDetailOf(String id) => '/jobs/$id';
  static const editJob = '/jobs/:id/edit';
  static String editJobOf(String id) => '/jobs/$id/edit';
  static const jobApply = '/jobs/:id/apply';
  static String jobApplyOf(String id) => '/jobs/$id/apply';

  static const startups = '/startups';
  static const newStartup = '/startups/new';
  static const startupDetail = '/startups/:id';
  static String startupDetailOf(String id) => '/startups/$id';

  static const mentors = '/mentors';
  static const mentorDetail = '/mentors/:id';
  static String mentorDetailOf(String id) => '/mentors/$id';
  static const mentorProfileForm = '/mentors/me/manage';

  static const local = '/local';
  static const localSetup = '/local/setup';
  static const localConnections = '/local/connections';
  static const localProfileDetail = '/local/:id';
  static String localProfileDetailOf(String id) => '/local/$id';
  static const meetup = '/local/meetup/:id';
  static String meetupOf(String localConnectionId) =>
      '/local/meetup/$localConnectionId';

  static const communities = '/communities';
  static const newCommunity = '/communities/new';
  static const communityDetail = '/communities/:id';
  static String communityDetailOf(String id) => '/communities/$id';
  static const editCommunity = '/communities/:id/edit';
  static String editCommunityOf(String id) => '/communities/$id/edit';
  static const communityMembers = '/communities/:id/members';
  static String communityMembersOf(String id) => '/communities/$id/members';
  static const communityChat = '/communities/:id/chat';
  static String communityChatOf(String id) => '/communities/$id/chat';

  static const events = '/events';
  static const newEvent = '/events/new';
  static const eventDetail = '/events/:id';
  static String eventDetailOf(String id) => '/events/$id';
  static const editEvent = '/events/:id/edit';
  static String editEventOf(String id) => '/events/$id/edit';

  static const news = '/news';
  static const newsSaved = '/news/saved';
  // No :id — news articles come live from an API with no stable server-side
  // id, so the item is passed via `extra` instead of a path param.
  static const newsDetail = '/news/detail';

  static const adminReports = '/admin/reports';

  static const posts = '/posts';
  static const newPost = '/posts/new';
  static const postDetail = '/posts/:id';
  static String postDetailOf(String id) => '/posts/$id';

  static const referrals = '/referrals';
  static const newReferralOffer = '/referrals/new';
  static const referralOfferDetail = '/referrals/:id';
  static String referralOfferDetailOf(String id) => '/referrals/$id';
  static const myReferralRequests = '/referrals/requests';

  static const interviewPractice = '/interview-practice';
  static const editInterviewPracticeProfile = '/interview-practice/setup';
  static const interviewPracticePartnerDetail = '/interview-practice/:id';
  static String interviewPracticePartnerDetailOf(String id) =>
      '/interview-practice/$id';
  static const myInterviewPracticeRequests = '/interview-practice/requests';

  static const intents = '/intents';
  static const newIntent = '/intents/new';
  static const myIntents = '/intents/mine';
  static const intentDetail = '/intents/:id';
  static String intentDetailOf(String id) => '/intents/$id';
  static const editIntent = '/intents/:id/edit';
  static String editIntentOf(String id) => '/intents/$id/edit';
  static const intentMatches = '/intents/:id/matches';
  static String intentMatchesOf(String id) => '/intents/$id/matches';
}
