import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../domain/entities/community.dart';
import '../../domain/repositories/community_repository.dart';

export '../../domain/community_action.dart';
export '../../domain/entities/community.dart';
export '../../domain/repositories/community_repository.dart' show CommunityFilters;

final communityRepositoryProvider =
    Provider<CommunityRepository>((ref) => CommunityRepositoryImpl(supabase));

final communityFiltersProvider = StateProvider<CommunityFilters>((ref) => const CommunityFilters());

final communitiesListProvider = FutureProvider<List<Community>>((ref) {
  final filters = ref.watch(communityFiltersProvider);
  return ref.watch(communityRepositoryProvider).listCommunities(filters: filters);
});

final communityDetailProvider = FutureProvider.family<Community, String>((ref, id) {
  return ref.watch(communityRepositoryProvider).getCommunity(id);
});

final isCommunityMemberProvider = FutureProvider.family<bool, String>((ref, communityId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;
  return ref.watch(communityRepositoryProvider).isMember(communityId, user.id);
});

final communityMembersProvider = FutureProvider.family<List<CommunityMember>, String>((ref, communityId) {
  return ref.watch(communityRepositoryProvider).listMembers(communityId);
});

final communityPostsProvider = FutureProvider.family<List<CommunityPost>, String>((ref, communityId) {
  return ref.watch(communityRepositoryProvider).getPosts(communityId);
});

final communityAnnouncementsProvider = FutureProvider.family<List<CommunityPost>, String>((ref, communityId) {
  return ref.watch(communityRepositoryProvider).getPosts(communityId, announcementsOnly: true);
});

final communityCommentsProvider = FutureProvider.family<List<CommunityComment>, String>((ref, postId) {
  return ref.watch(communityRepositoryProvider).getComments(postId);
});

/// Pre-join Q&A — distinct from [communityPostsProvider] (spec: never
/// mixed into the same feed).
final communityQuestionsProvider = FutureProvider.family<List<CommunityQuestion>, String>((ref, communityId) {
  return ref.watch(communityRepositoryProvider).listQuestions(communityId);
});

final myCommunityJoinRequestProvider = FutureProvider.family<CommunityJoinRequest?, String>((ref, communityId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(communityRepositoryProvider).myPendingJoinRequest(communityId);
});

/// Owner-only: every pending join request for their community.
final communityJoinRequestsProvider = FutureProvider.family<List<CommunityJoinRequest>, String>((ref, communityId) {
  return ref.watch(communityRepositoryProvider).listJoinRequests(communityId);
});

final communityConversationIdProvider = FutureProvider.family<String?, String>((ref, communityId) {
  return ref.watch(communityRepositoryProvider).getCommunityConversationId(communityId);
});

class CommunityController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _invalidateCommunity(String communityId) {
    ref.invalidate(communityDetailProvider(communityId));
    ref.invalidate(isCommunityMemberProvider(communityId));
    ref.invalidate(communityMembersProvider(communityId));
    ref.invalidate(myCommunityJoinRequestProvider(communityId));
    ref.invalidate(communityJoinRequestsProvider(communityId));
    ref.invalidate(communityConversationIdProvider(communityId));
  }

  Future<Community?> createCommunity(Map<String, dynamic> data, {List<String> topicSkillIds = const []}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(communityRepositoryProvider).createCommunity(data, topicSkillIds: topicSkillIds),
    );
    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    if (!result.hasError) ref.invalidate(communitiesListProvider);
    return result.valueOrNull;
  }

  Future<bool> updateCommunity(String communityId, Map<String, dynamic> changes, {List<String>? topicSkillIds}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(communityRepositoryProvider).updateCommunity(communityId, changes, topicSkillIds: topicSkillIds),
    );
    state = result;
    if (!result.hasError) {
      _invalidateCommunity(communityId);
      ref.invalidate(communitiesListProvider);
    }
    return !result.hasError;
  }

  Future<bool> join(String communityId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(communityRepositoryProvider).joinCommunity(communityId));
    state = result;
    if (!result.hasError) _invalidateCommunity(communityId);
    return !result.hasError;
  }

  Future<bool> requestToJoin(String communityId, {String? message}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(communityRepositoryProvider).requestToJoinCommunity(communityId, message: message),
    );
    state = result;
    if (!result.hasError) _invalidateCommunity(communityId);
    return !result.hasError;
  }

  Future<bool> cancelJoinRequest(String requestId, String communityId) async {
    state = const AsyncLoading();
    final result =
        await AsyncValue.guard(() => ref.read(communityRepositoryProvider).cancelJoinRequest(requestId));
    state = result;
    if (!result.hasError) _invalidateCommunity(communityId);
    return !result.hasError;
  }

  Future<bool> respondToJoinRequest(String requestId, String communityId, {required bool accept}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(communityRepositoryProvider).respondToJoinRequest(requestId, accept: accept),
    );
    state = result;
    if (!result.hasError) _invalidateCommunity(communityId);
    return !result.hasError;
  }

  Future<bool> leave(String communityId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(communityRepositoryProvider).leaveCommunity(communityId));
    state = result;
    if (!result.hasError) _invalidateCommunity(communityId);
    return !result.hasError;
  }

  Future<bool> removeMember(String communityId, String profileId) async {
    state = const AsyncLoading();
    final result =
        await AsyncValue.guard(() => ref.read(communityRepositoryProvider).removeMember(communityId, profileId));
    state = result;
    if (!result.hasError) _invalidateCommunity(communityId);
    return !result.hasError;
  }

  Future<bool> setMemberRole(String communityId, String profileId, String role) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(communityRepositoryProvider).setMemberRole(communityId, profileId, role),
    );
    state = result;
    if (!result.hasError) ref.invalidate(communityMembersProvider(communityId));
    return !result.hasError;
  }

  Future<bool> createPost(String communityId, String content, {bool isAnnouncement = false}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(communityRepositoryProvider).createPost(communityId, content, isAnnouncement: isAnnouncement),
    );
    state = result;
    if (!result.hasError) {
      ref.invalidate(communityPostsProvider(communityId));
      if (isAnnouncement) ref.invalidate(communityAnnouncementsProvider(communityId));
    }
    return !result.hasError;
  }

  Future<bool> createComment(String postId, String communityId, String content) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(communityRepositoryProvider).createComment(postId, content));
    state = result;
    if (!result.hasError) {
      ref.invalidate(communityCommentsProvider(postId));
      ref.invalidate(communityPostsProvider(communityId));
    }
    return !result.hasError;
  }

  Future<bool> askQuestion(String communityId, String questionText) async {
    state = const AsyncLoading();
    final result =
        await AsyncValue.guard(() => ref.read(communityRepositoryProvider).askQuestion(communityId, questionText));
    state = result;
    if (!result.hasError) ref.invalidate(communityQuestionsProvider(communityId));
    return !result.hasError;
  }

  Future<bool> answerQuestion(String questionId, String communityId, String answerText) async {
    state = const AsyncLoading();
    final result =
        await AsyncValue.guard(() => ref.read(communityRepositoryProvider).answerQuestion(questionId, answerText));
    state = result;
    if (!result.hasError) ref.invalidate(communityQuestionsProvider(communityId));
    return !result.hasError;
  }

  Future<String?> uploadLogo(String communityId, List<int> bytes, String fileExt) async {
    try {
      return await ref.read(communityRepositoryProvider).uploadLogo(communityId, bytes, fileExt);
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadCoverImage(String communityId, List<int> bytes, String fileExt) async {
    try {
      return await ref.read(communityRepositoryProvider).uploadCoverImage(communityId, bytes, fileExt);
    } catch (_) {
      return null;
    }
  }
}

final communityControllerProvider =
    AsyncNotifierProvider<CommunityController, void>(CommunityController.new);
