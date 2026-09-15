import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_reports_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/communities/presentation/screens/communities_list_screen.dart';
import '../../features/communities/presentation/screens/community_chat_screen.dart';
import '../../features/communities/presentation/screens/community_detail_screen.dart';
import '../../features/communities/presentation/screens/community_members_screen.dart';
import '../../features/communities/presentation/screens/create_community_screen.dart';
import '../../features/connections/presentation/screens/blocked_users_screen.dart';
import '../../features/connections/presentation/screens/connections_screen.dart';
import '../../features/connections/presentation/screens/buddies_screen.dart';
import '../../features/events/presentation/screens/create_event_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/hackathons/presentation/screens/create_team_requirement_screen.dart';
import '../../features/hackathons/presentation/screens/hackathon_detail_screen.dart';
import '../../features/hackathons/presentation/screens/hackathons_list_screen.dart';
import '../../features/hackathons/presentation/screens/team_chat_screen.dart';
import '../../features/hackathons/presentation/screens/team_detail_screen.dart';
import '../../features/home/presentation/screens/create_menu_screen.dart';
import '../../features/intents/presentation/screens/create_intent_screen.dart';
import '../../features/intents/presentation/screens/intent_detail_screen.dart';
import '../../features/intents/presentation/screens/intent_matches_screen.dart';
import '../../features/intents/presentation/screens/intents_list_screen.dart';
import '../../features/intents/presentation/screens/my_intents_screen.dart';
import '../../features/interview_practice/presentation/screens/edit_interview_practice_profile_screen.dart';
import '../../features/interview_practice/presentation/screens/interview_practice_list_screen.dart';
import '../../features/interview_practice/presentation/screens/interview_practice_partner_detail_screen.dart';
import '../../features/interview_practice/presentation/screens/my_interview_practice_requests_screen.dart';
import '../../features/home/presentation/screens/discover_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/main_shell.dart';
import '../../features/local/presentation/screens/local_connections_screen.dart';
import '../../features/local/presentation/screens/local_discovery_screen.dart';
import '../../features/local/presentation/screens/local_profile_detail_screen.dart';
import '../../features/local/presentation/screens/local_setup_screen.dart';
import '../../features/local/presentation/screens/meetup_screen.dart';
import '../../features/mentorship/presentation/screens/create_mentor_profile_screen.dart';
import '../../features/mentorship/presentation/screens/mentor_detail_screen.dart';
import '../../features/mentorship/presentation/screens/mentors_list_screen.dart';
import '../../features/messaging/presentation/screens/chat_screen.dart';
import '../../features/messaging/presentation/screens/conversations_screen.dart';
import '../../features/news/domain/entities/news_item.dart';
import '../../features/news/presentation/screens/news_detail_screen.dart';
import '../../features/news/presentation/screens/news_list_screen.dart';
import '../../features/news/presentation/screens/saved_news_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/people/presentation/screens/people_list_screen.dart';
import '../../features/posts/presentation/screens/create_post_screen.dart';
import '../../features/posts/presentation/screens/post_detail_screen.dart';
import '../../features/posts/presentation/screens/posts_feed_screen.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/projects/presentation/screens/create_project_screen.dart';
import '../../features/projects/presentation/screens/project_detail_screen.dart';
import '../../features/projects/presentation/screens/projects_list_screen.dart';
import '../../features/jobs/presentation/screens/create_job_screen.dart';
import '../../features/jobs/presentation/screens/job_application_screen.dart';
import '../../features/jobs/presentation/screens/job_detail_screen.dart';
import '../../features/jobs/presentation/screens/jobs_list_screen.dart';
import '../../features/referrals/presentation/screens/create_referral_offer_screen.dart';
import '../../features/referrals/presentation/screens/my_referral_requests_screen.dart';
import '../../features/referrals/presentation/screens/referral_offer_detail_screen.dart';
import '../../features/referrals/presentation/screens/referrals_list_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/app_icon_screen.dart';
import '../../features/settings/presentation/screens/profile_photo_privacy_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/startups/presentation/screens/create_startup_screen.dart';
import '../../features/startups/presentation/screens/startup_detail_screen.dart';
import '../../features/startups/presentation/screens/startups_list_screen.dart';

part 'route_paths.dart';

/// Root navigator key lets us push full-screen routes (detail screens, forms)
/// on top of the bottom-nav shell instead of nesting them inside a tab.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: false,
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) async {
      final loc = state.matchedLocation;
      final isAuthRoute = loc == RoutePaths.signIn ||
          loc == RoutePaths.signUp ||
          loc == RoutePaths.forgotPassword;

      // While auth state is still resolving, stay on splash.
      if (authState.isLoading) {
        return loc == RoutePaths.splash ? null : RoutePaths.splash;
      }

      final user = authState.valueOrNull;
      final signedIn = user != null;

      if (!signedIn) {
        return isAuthRoute ? null : RoutePaths.signIn;
      }

      // Signed in: check profile completion (spec section 52).
      if (loc == RoutePaths.splash || isAuthRoute) {
        final profile = await ref.read(myProfileProvider.future);
        return (profile?.profileCompleted ?? false)
            ? RoutePaths.home
            : RoutePaths.onboarding;
      }

      if (loc == RoutePaths.onboarding) {
        final profile = await ref.read(myProfileProvider.future);
        if (profile?.profileCompleted ?? false) return RoutePaths.home;
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
          path: RoutePaths.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: RoutePaths.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(
          path: RoutePaths.signUp, builder: (_, __) => const SignUpScreen()),
      GoRoute(
          path: RoutePaths.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: RoutePaths.onboarding,
          builder: (_, __) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: RoutePaths.home, builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: RoutePaths.discover,
                builder: (_, __) => const DiscoverScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: RoutePaths.create,
                builder: (_, __) => const CreateMenuScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: RoutePaths.messages,
                builder: (_, __) => const ConversationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: RoutePaths.profile,
                builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
          path: RoutePaths.editProfile,
          builder: (_, __) => const EditProfileScreen()),
      GoRoute(
          path: RoutePaths.settings,
          builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: RoutePaths.appIconSettings,
          builder: (_, __) => const AppIconScreen()),
      GoRoute(
          path: RoutePaths.profilePhotoPrivacy,
          builder: (_, __) => const ProfilePhotoPrivacyScreen()),
      GoRoute(
          path: RoutePaths.notifications,
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: RoutePaths.search, builder: (_, __) => const SearchScreen()),
      GoRoute(
          path: RoutePaths.connections,
          builder: (_, __) => const ConnectionsScreen()),
      GoRoute(
          path: RoutePaths.buddies,
          builder: (_, __) => const BuddiesScreen()),
      GoRoute(
          path: RoutePaths.blockedUsers,
          builder: (_, __) => const BlockedUsersScreen()),
      GoRoute(
        path: RoutePaths.chat,
        builder: (_, state) => ChatScreen(
          conversationId: state.pathParameters['id']!,
          initialText: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
          path: RoutePaths.people,
          builder: (_, __) => const PeopleListScreen()),
      GoRoute(
        path: RoutePaths.personDetail,
        builder: (_, state) =>
            PeopleProfileRoute(profileId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.hackathons,
          builder: (_, __) => const HackathonsListScreen()),
      GoRoute(
        path: RoutePaths.newTeamRequirementStandalone,
        builder: (_, __) => const CreateTeamRequirementScreen(),
      ),
      GoRoute(
        path: RoutePaths.hackathonDetail,
        builder: (_, state) =>
            HackathonDetailScreen(hackathonId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.newTeamRequirement,
        builder: (_, state) => CreateTeamRequirementScreen(
          hackathonId: state.pathParameters['id']!,
          hackathonName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: RoutePaths.teamDetail,
        builder: (_, state) =>
            TeamDetailScreen(teamRequirementId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.editTeamRequirement,
        builder: (_, state) =>
            CreateTeamRequirementScreen(editTeamRequirementId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.teamChat,
        builder: (_, state) => TeamChatScreen(
          teamRequirementId: state.pathParameters['id']!,
          teamName: state.extra as String?,
        ),
      ),
      GoRoute(
          path: RoutePaths.projects,
          builder: (_, __) => const ProjectsListScreen()),
      GoRoute(
          path: RoutePaths.newProject,
          builder: (_, __) => const CreateProjectScreen()),
      GoRoute(
        path: RoutePaths.projectDetail,
        builder: (_, state) =>
            ProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.jobs, builder: (_, __) => const JobsListScreen()),
      GoRoute(
          path: RoutePaths.newJob, builder: (_, __) => const CreateJobScreen()),
      GoRoute(
        path: RoutePaths.jobDetail,
        builder: (_, state) =>
            JobDetailScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.editJob,
        builder: (_, state) =>
            CreateJobScreen(editJobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.jobApply,
        builder: (_, state) =>
            JobApplicationScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.intents, builder: (_, __) => const IntentsListScreen()),
      GoRoute(
          path: RoutePaths.myIntents, builder: (_, __) => const MyIntentsScreen()),
      GoRoute(
          path: RoutePaths.newIntent, builder: (_, __) => const CreateIntentScreen()),
      GoRoute(
        path: RoutePaths.intentDetail,
        builder: (_, state) =>
            IntentDetailScreen(intentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.editIntent,
        builder: (_, state) =>
            CreateIntentScreen(editIntentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.intentMatches,
        builder: (_, state) =>
            IntentMatchesScreen(intentId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.referrals,
          builder: (_, __) => const ReferralsListScreen()),
      GoRoute(
          path: RoutePaths.newReferralOffer,
          builder: (_, __) => const CreateReferralOfferScreen()),
      GoRoute(
          path: RoutePaths.myReferralRequests,
          builder: (_, __) => const MyReferralRequestsScreen()),
      GoRoute(
        path: RoutePaths.referralOfferDetail,
        builder: (_, state) =>
            ReferralOfferDetailScreen(offerId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.interviewPractice,
          builder: (_, __) => const InterviewPracticeListScreen()),
      GoRoute(
          path: RoutePaths.editInterviewPracticeProfile,
          builder: (_, __) => const EditInterviewPracticeProfileScreen()),
      GoRoute(
          path: RoutePaths.myInterviewPracticeRequests,
          builder: (_, __) => const MyInterviewPracticeRequestsScreen()),
      GoRoute(
        path: RoutePaths.interviewPracticePartnerDetail,
        builder: (_, state) => InterviewPracticePartnerDetailScreen(
            profileId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.startups,
          builder: (_, __) => const StartupsListScreen()),
      GoRoute(
          path: RoutePaths.newStartup,
          builder: (_, __) => const CreateStartupScreen()),
      GoRoute(
        path: RoutePaths.startupDetail,
        builder: (_, state) =>
            StartupDetailScreen(startupId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.mentors,
          builder: (_, __) => const MentorsListScreen()),
      GoRoute(
        path: RoutePaths.mentorDetail,
        builder: (_, state) =>
            MentorDetailScreen(mentorId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.mentorProfileForm,
          builder: (_, __) => const CreateMentorProfileScreen()),
      GoRoute(
          path: RoutePaths.local,
          builder: (_, __) => const LocalDiscoveryScreen()),
      GoRoute(
          path: RoutePaths.localSetup,
          builder: (_, __) => const LocalSetupScreen()),
      GoRoute(
          path: RoutePaths.localConnections,
          builder: (_, __) => const LocalConnectionsScreen()),
      GoRoute(
        path: RoutePaths.localProfileDetail,
        builder: (_, state) =>
            LocalProfileDetailScreen(profileId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.meetup,
        builder: (_, state) =>
            MeetupScreen(localConnectionId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.communities,
          builder: (_, __) => const CommunitiesListScreen()),
      GoRoute(
          path: RoutePaths.newCommunity,
          builder: (_, __) => const CreateCommunityScreen()),
      GoRoute(
        path: RoutePaths.communityDetail,
        builder: (_, state) =>
            CommunityDetailScreen(communityId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.editCommunity,
        builder: (_, state) =>
            CreateCommunityScreen(editCommunityId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.communityMembers,
        builder: (_, state) =>
            CommunityMembersScreen(communityId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.communityChat,
        builder: (_, state) => CommunityChatScreen(
          communityId: state.pathParameters['id']!,
          communityName: state.extra as String?,
        ),
      ),
      GoRoute(
          path: RoutePaths.events,
          builder: (_, __) => const EventsListScreen()),
      GoRoute(
          path: RoutePaths.newEvent,
          builder: (_, __) => const CreateEventScreen()),
      GoRoute(
        path: RoutePaths.eventDetail,
        builder: (_, state) =>
            EventDetailScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.editEvent,
        builder: (_, state) =>
            CreateEventScreen(editEventId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: RoutePaths.news, builder: (_, __) => const NewsListScreen()),
      GoRoute(
          path: RoutePaths.newsSaved,
          builder: (_, __) => const SavedNewsScreen()),
      GoRoute(
        path: RoutePaths.newsDetail,
        builder: (_, state) => NewsDetailScreen(item: state.extra as NewsItem),
      ),
      GoRoute(
          path: RoutePaths.adminReports,
          builder: (_, __) => const AdminReportsScreen()),
      GoRoute(
          path: RoutePaths.posts, builder: (_, __) => const PostsFeedScreen()),
      GoRoute(
          path: RoutePaths.newPost,
          builder: (_, __) => const CreatePostScreen()),
      GoRoute(
        path: RoutePaths.postDetail,
        builder: (_, state) =>
            PostDetailScreen(postId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Bridges Riverpod's auth stream into a [Listenable] so GoRouter re-runs
/// its redirect logic whenever sign-in state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    _sub = ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Thin wrapper so /people/:id can resolve either another user's profile or
/// redirect to /profile when viewing your own id — kept in this file to
/// avoid a circular import between routing and the people feature.
class PeopleProfileRoute extends ConsumerWidget {
  const PeopleProfileRoute({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProfileScreen(profileId: profileId);
  }
}
