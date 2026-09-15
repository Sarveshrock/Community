import '../entities/community.dart';

class CommunityFilters {
  const CommunityFilters({this.query, this.communityType, this.accessType});

  final String? query;
  final String? communityType;
  final String? accessType;

  bool get isEmpty => query == null && communityType == null && accessType == null;

  CommunityFilters copyWith({String? query, Object? communityType = _unset, Object? accessType = _unset}) {
    return CommunityFilters(
      query: query ?? this.query,
      communityType: identical(communityType, _unset) ? this.communityType : communityType as String?,
      accessType: identical(accessType, _unset) ? this.accessType : accessType as String?,
    );
  }
}

const _unset = Object();

abstract class CommunityRepository {
  Future<List<Community>> listCommunities({CommunityFilters filters = const CommunityFilters()});
  Future<Community> getCommunity(String id);
  Future<bool> isMember(String communityId, String profileId);

  Future<Community> createCommunity(Map<String, dynamic> data, {List<String> topicSkillIds = const []});

  /// `changes` always applies. `topicSkillIds`, when non-null, fully
  /// replaces the community's topics (delete-then-insert).
  Future<void> updateCommunity(String communityId, Map<String, dynamic> changes, {List<String>? topicSkillIds});

  /// Public communities only — goes through `join_community()`, which
  /// rejects request-to-join/private communities server-side.
  Future<void> joinCommunity(String communityId);

  Future<String> requestToJoinCommunity(String communityId, {String? message});
  Future<void> cancelJoinRequest(String requestId);
  Future<void> respondToJoinRequest(String requestId, {required bool accept});
  Future<CommunityJoinRequest?> myPendingJoinRequest(String communityId);

  /// Owner-only: every pending join request for their community.
  Future<List<CommunityJoinRequest>> listJoinRequests(String communityId);

  Future<void> leaveCommunity(String communityId);
  Future<void> removeMember(String communityId, String profileId);
  Future<void> setMemberRole(String communityId, String profileId, String role);
  Future<List<CommunityMember>> listMembers(String communityId);

  Future<List<CommunityPost>> getPosts(String communityId, {bool announcementsOnly = false});
  Future<void> createPost(String communityId, String content, {bool isAnnouncement = false});
  Future<List<CommunityComment>> getComments(String postId);
  Future<void> createComment(String postId, String content);

  /// Pre-join Q&A — distinct from [getPosts]/[createPost] (spec: never
  /// mixed into the same feed).
  Future<List<CommunityQuestion>> listQuestions(String communityId);
  Future<void> askQuestion(String communityId, String questionText);
  Future<void> answerQuestion(String questionId, String answerText);

  /// The community's private group chat conversation id, or null if the
  /// caller isn't a member (RLS-filtered) or it hasn't been created yet.
  Future<String?> getCommunityConversationId(String communityId);

  Future<String> uploadLogo(String communityId, List<int> bytes, String fileExt);
  Future<String> uploadCoverImage(String communityId, List<int> bytes, String fileExt);
}
