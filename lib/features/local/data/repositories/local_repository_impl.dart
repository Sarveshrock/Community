import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/local_entities.dart';
import '../../domain/repositories/local_repository.dart';

class LocalRepositoryImpl implements LocalRepository {
  LocalRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _connectionSelect =
      '*, requester_profile:profiles!local_connections_requester_id_fkey(full_name, avatar_url), '
      'receiver_profile:profiles!local_connections_receiver_id_fkey(full_name, avatar_url)';

  @override
  Future<LocalProfile?> getMyLocalProfile(String profileId) async {
    try {
      final data = await _client
          .from(Tables.localProfiles)
          .select()
          .eq('profile_id', profileId)
          .maybeSingle();
      if (data == null) return null;

      final prefs = await _client
          .from(Tables.localPreferences)
          .select('activity_preferences, interest_preferences')
          .eq('profile_id', profileId)
          .maybeSingle();

      return LocalProfile.fromJson(
        data,
        activities: (prefs?['activity_preferences'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
        interests: (prefs?['interest_preferences'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
      );
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> upsertLocalProfile(
      String profileId, Map<String, dynamic> data) async {
    try {
      await _client
          .from(Tables.localProfiles)
          .upsert({'profile_id': profileId, ...data});
      // Local discovery participation also flips the profile-level flag used
      // by RLS / get_local_candidates().
      if (data.containsKey('enabled')) {
        await _client.from(Tables.profiles).update(
            {'local_discoverable': data['enabled']}).eq('id', profileId);
      }
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> setLocalPreferences(String profileId,
      {required List<String> activities,
      required List<String> interests}) async {
    try {
      await _client.from(Tables.localPreferences).upsert({
        'profile_id': profileId,
        'activity_preferences': activities,
        'interest_preferences': interests,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<LocalCandidate>> getCandidates({int limit = 20}) async {
    try {
      final data = await _client
          .rpc('get_local_candidates', params: {'result_limit': limit});
      return (data as List)
          .map((e) => LocalCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<LocalConnection>> getMyLocalConnections(String myId,
      {LocalConnectionStatus? status}) async {
    try {
      var query = _client
          .from(Tables.localConnections)
          .select(_connectionSelect)
          .or('requester_id.eq.$myId,receiver_id.eq.$myId');
      if (status != null) query = query.eq('status', status.value);
      final data = await query.order('created_at', ascending: false);
      return (data as List)
          .map((e) => LocalConnection.fromJson(e as Map<String, dynamic>,
              viewerId: myId))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<LocalConnection?> getLocalConnectionBetween(
      String myId, String otherId) async {
    try {
      final data = await _client
          .from(Tables.localConnections)
          .select(_connectionSelect)
          .or('and(requester_id.eq.$myId,receiver_id.eq.$otherId),and(requester_id.eq.$otherId,receiver_id.eq.$myId)')
          .maybeSingle();
      if (data == null) return null;
      return LocalConnection.fromJson(data, viewerId: myId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> sendLocalRequest(String receiverId) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.localConnections).insert({
        'requester_id': myId,
        'receiver_id': receiverId,
        'status': 'pending',
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> respondToLocalRequest(String connectionId,
      {required bool accept}) async {
    try {
      await _client.from(Tables.localConnections).update(
          {'status': accept ? 'accepted' : 'declined'}).eq('id', connectionId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<MeetupSuggestion>> getMeetupsForConnection(
      String localConnectionId) async {
    try {
      final data = await _client
          .from(Tables.meetupSuggestions)
          .select()
          .eq('local_connection_id', localConnectionId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => MeetupSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> suggestMeetup(Map<String, dynamic> data) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client
          .from(Tables.meetupSuggestions)
          .insert({...data, 'suggested_by': myId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> respondToMeetup(String meetupId, {required bool accept}) async {
    try {
      await _client.from(Tables.meetupSuggestions).update(
          {'status': accept ? 'accepted' : 'declined'}).eq('id', meetupId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
