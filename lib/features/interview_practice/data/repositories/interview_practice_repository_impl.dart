import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/interview_practice.dart';
import '../../domain/repositories/interview_practice_repository.dart';

class InterviewPracticeRepositoryImpl implements InterviewPracticeRepository {
  InterviewPracticeRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _profileSelect =
      '*, profiles!interview_practice_profiles_profile_id_fkey(full_name, avatar_url, current_role)';

  static const _requestSelect = '*, '
      'requester:profiles!interview_practice_requests_requester_id_fkey(full_name, avatar_url), '
      'partner:profiles!interview_practice_requests_partner_id_fkey(full_name, avatar_url)';

  @override
  Future<List<InterviewPracticeProfile>> listPool({int limit = 20, int offset = 0}) async {
    try {
      final myId = _client.auth.currentUser?.id;
      var query = _client
          .from(Tables.interviewPracticeProfiles)
          .select(_profileSelect)
          .eq('is_active', true);
      if (myId != null) query = query.neq('profile_id', myId);
      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => InterviewPracticeProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<InterviewPracticeProfile?> myProfile() async {
    try {
      final myId = _client.auth.currentUser!.id;
      final data = await _client
          .from(Tables.interviewPracticeProfiles)
          .select(_profileSelect)
          .eq('profile_id', myId)
          .maybeSingle();
      return data == null ? null : InterviewPracticeProfile.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<InterviewPracticeProfile> getProfile(String profileId) async {
    try {
      final data = await _client
          .from(Tables.interviewPracticeProfiles)
          .select(_profileSelect)
          .eq('profile_id', profileId)
          .single();
      return InterviewPracticeProfile.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> upsertMyProfile(Map<String, dynamic> data) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client
          .from(Tables.interviewPracticeProfiles)
          .upsert({'profile_id': myId, ...data});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<InterviewPracticeRequest>> listSentRequests() async {
    try {
      final myId = _client.auth.currentUser!.id;
      final data = await _client
          .from(Tables.interviewPracticeRequests)
          .select(_requestSelect)
          .eq('requester_id', myId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => InterviewPracticeRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<InterviewPracticeRequest>> listReceivedRequests() async {
    try {
      final myId = _client.auth.currentUser!.id;
      final data = await _client
          .from(Tables.interviewPracticeRequests)
          .select(_requestSelect)
          .eq('partner_id', myId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => InterviewPracticeRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> requestPractice(String partnerId,
      {required String targetRole, String? message}) async {
    try {
      final id = await _client.rpc('request_interview_practice', params: {
        'p_partner_id': partnerId,
        'p_target_role': targetRole,
        'p_message': message,
      });
      return id as String;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> respondToRequest(String requestId, {required bool accept}) async {
    try {
      await _client.rpc('respond_to_interview_practice_request', params: {
        'p_request_id': requestId,
        'p_accept': accept,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> cancelRequest(String requestId) async {
    try {
      await _client.rpc('cancel_interview_practice_request',
          params: {'p_request_id': requestId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> markCompleted(String requestId) async {
    try {
      await _client.rpc('mark_interview_practice_completed',
          params: {'p_request_id': requestId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
