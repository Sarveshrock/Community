import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/community.dart';
import '../../domain/repositories/community_repository.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _listSelect = '*, community_members(profile_id), community_topics(skills(name))';

  @override
  Future<List<Community>> listCommunities({CommunityFilters filters = const CommunityFilters()}) async {
    try {
      var query = _client.from(Tables.communities).select(_listSelect);
      if (filters.communityType != null) query = query.eq('community_type', filters.communityType!);
      if (filters.accessType != null) query = query.eq('access_type', filters.accessType!);
      if (filters.query != null && filters.query!.isNotEmpty) {
        query = query.or('name.ilike.%${filters.query}%,tagline.ilike.%${filters.query}%');
      }
      final data = await query.order('created_at', ascending: false).limit(50);
      return (data as List).map((e) => Community.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Community> getCommunity(String id) async {
    try {
      final data = await _client.from(Tables.communities).select(_listSelect).eq('id', id).single();
      return Community.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<bool> isMember(String communityId, String profileId) async {
    try {
      final data = await _client
          .from(Tables.communityMembers)
          .select('profile_id')
          .eq('community_id', communityId)
          .eq('profile_id', profileId)
          .maybeSingle();
      return data != null;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Community> createCommunity(Map<String, dynamic> data, {List<String> topicSkillIds = const []}) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client.from(Tables.communities).insert({...data, 'owner_id': myId}).select().single();
      final communityId = inserted['id'] as String;
      await _client
          .from(Tables.communityMembers)
          .insert({'community_id': communityId, 'profile_id': myId, 'role': 'admin'});
      if (topicSkillIds.isNotEmpty) {
        await _client.from(Tables.communityTopics).insert([
          for (final skillId in topicSkillIds) {'community_id': communityId, 'skill_id': skillId},
        ]);
      }
      // Every community gets a private group chat from the moment it
      // exists, exactly like hackathon teams (0028_team_management.sql).
      await _client.rpc('create_community_conversation', params: {'p_community_id': communityId});
      final full = await _client.from(Tables.communities).select(_listSelect).eq('id', communityId).single();
      return Community.fromJson(full);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> updateCommunity(String communityId, Map<String, dynamic> changes, {List<String>? topicSkillIds}) async {
    try {
      if (changes.isNotEmpty) {
        await _client.from(Tables.communities).update(changes).eq('id', communityId);
      }
      if (topicSkillIds != null) {
        await _client.from(Tables.communityTopics).delete().eq('community_id', communityId);
        if (topicSkillIds.isNotEmpty) {
          await _client.from(Tables.communityTopics).insert([
            for (final skillId in topicSkillIds) {'community_id': communityId, 'skill_id': skillId},
          ]);
        }
      }
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> joinCommunity(String communityId) async {
    try {
      await _client.rpc('join_community', params: {'p_community_id': communityId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> requestToJoinCommunity(String communityId, {String? message}) async {
    try {
      final id = await _client.rpc('request_to_join_community', params: {
        'p_community_id': communityId,
        'p_message': message,
      });
      return id as String;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> cancelJoinRequest(String requestId) async {
    try {
      await _client.rpc('cancel_community_join_request', params: {'p_request_id': requestId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> respondToJoinRequest(String requestId, {required bool accept}) async {
    try {
      await _client.rpc('respond_to_community_join_request', params: {
        'p_request_id': requestId,
        'p_accept': accept,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<CommunityJoinRequest?> myPendingJoinRequest(String communityId) async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return null;
      final data = await _client
          .from(Tables.communityJoinRequests)
          .select()
          .eq('community_id', communityId)
          .eq('requester_id', myId)
          .eq('status', 'pending')
          .maybeSingle();
      return data == null ? null : CommunityJoinRequest.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<CommunityJoinRequest>> listJoinRequests(String communityId) async {
    try {
      final data = await _client
          .from(Tables.communityJoinRequests)
          .select('*, profiles(full_name, avatar_url)')
          .eq('community_id', communityId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return (data as List).map((e) => CommunityJoinRequest.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> leaveCommunity(String communityId) async {
    try {
      await _client.rpc('leave_community', params: {'p_community_id': communityId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> removeMember(String communityId, String profileId) async {
    try {
      await _client.rpc('remove_community_member', params: {
        'p_community_id': communityId,
        'p_profile_id': profileId,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> setMemberRole(String communityId, String profileId, String role) async {
    try {
      await _client.rpc('set_community_member_role', params: {
        'p_community_id': communityId,
        'p_profile_id': profileId,
        'p_role': role,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<CommunityMember>> listMembers(String communityId) async {
    try {
      final data = await _client
          .from(Tables.communityMembers)
          .select('*, profiles(full_name, avatar_url, current_role, current_company)')
          .eq('community_id', communityId)
          .order('joined_at');
      return (data as List).map((e) => CommunityMember.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<CommunityPost>> getPosts(String communityId, {bool announcementsOnly = false}) async {
    try {
      var query = _client
          .from(Tables.communityPosts)
          .select('*, profiles(full_name, avatar_url), community_comments(id)')
          .eq('community_id', communityId)
          .filter('deleted_at', 'is', null);
      if (announcementsOnly) query = query.eq('is_announcement', true);
      final data = await query.order('created_at', ascending: false);
      return (data as List).map((e) => CommunityPost.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> createPost(String communityId, String content, {bool isAnnouncement = false}) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.communityPosts).insert({
        'community_id': communityId,
        'author_id': myId,
        'content': content,
        'is_announcement': isAnnouncement,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<CommunityComment>> getComments(String postId) async {
    try {
      final data = await _client
          .from(Tables.communityComments)
          .select('*, profiles(full_name, avatar_url)')
          .eq('post_id', postId)
          .filter('deleted_at', 'is', null)
          .order('created_at');
      return (data as List).map((e) => CommunityComment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> createComment(String postId, String content) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.communityComments).insert({
        'post_id': postId,
        'author_id': myId,
        'content': content,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<CommunityQuestion>> listQuestions(String communityId) async {
    try {
      final data = await _client
          .from(Tables.communityQuestions)
          .select('*, profiles(full_name, avatar_url), community_answers(*, profiles(full_name, avatar_url))')
          .eq('community_id', communityId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => CommunityQuestion.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> askQuestion(String communityId, String questionText) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.communityQuestions).insert({
        'community_id': communityId,
        'asker_id': myId,
        'question_text': questionText,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> answerQuestion(String questionId, String answerText) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.communityAnswers).insert({
        'question_id': questionId,
        'responder_id': myId,
        'answer_text': answerText,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String?> getCommunityConversationId(String communityId) async {
    try {
      final data =
          await _client.from(Tables.conversations).select('id').eq('community_id', communityId).maybeSingle();
      return data?['id'] as String?;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> uploadLogo(String communityId, List<int> bytes, String fileExt) async {
    try {
      final path = 'communities/$communityId/logo.$fileExt';
      await _client.storage.from(StorageBuckets.communityMedia).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from(StorageBuckets.communityMedia).getPublicUrl(path);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> uploadCoverImage(String communityId, List<int> bytes, String fileExt) async {
    try {
      final path = 'communities/$communityId/cover.$fileExt';
      await _client.storage.from(StorageBuckets.communityMedia).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from(StorageBuckets.communityMedia).getPublicUrl(path);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
