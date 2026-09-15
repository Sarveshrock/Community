import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../matching/domain/entities/intent_recommendation.dart';
import '../../../matching/domain/entities/match_result.dart';
import '../../domain/entities/intent.dart';
import '../../domain/repositories/intent_repository.dart';

class IntentRepositoryImpl implements IntentRepository {
  IntentRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, profiles(full_name, avatar_url, current_role), intent_skills(direction, skills(name))';

  static const _matchSelect =
      '*, profiles(full_name, avatar_url, current_role, current_company)';

  @override
  Future<List<UserIntent>> listPublicIntents({int limit = 20, int offset = 0}) async {
    try {
      final data = await _client
          .from(Tables.intents)
          .select(_select)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => UserIntent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<UserIntent>> myIntents() async {
    try {
      final myId = _client.auth.currentUser!.id;
      final data = await _client
          .from(Tables.intents)
          .select(_select)
          .eq('profile_id', myId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => UserIntent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<UserIntent> getIntent(String id) async {
    try {
      final data = await _client
          .from(Tables.intents)
          .select(_select)
          .eq('id', id)
          .single();
      return UserIntent.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<UserIntent> createIntent(
    Map<String, dynamic> data, {
    required List<String> skillsNeededIds,
    required List<String> skillsOfferedIds,
  }) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client
          .from(Tables.intents)
          .insert({...data, 'profile_id': myId})
          .select()
          .single();
      final intentId = inserted['id'] as String;

      final skillRows = [
        for (final skillId in skillsNeededIds)
          {'intent_id': intentId, 'skill_id': skillId, 'direction': 'needed'},
        for (final skillId in skillsOfferedIds)
          {'intent_id': intentId, 'skill_id': skillId, 'direction': 'offered'},
      ];
      if (skillRows.isNotEmpty) {
        await _client.from(Tables.intentSkills).insert(skillRows);
      }

      return await getIntent(intentId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<UserIntent> updateIntent(
    String intentId,
    Map<String, dynamic> data, {
    List<String>? skillsNeededIds,
    List<String>? skillsOfferedIds,
  }) async {
    try {
      if (data.isNotEmpty) {
        await _client.from(Tables.intents).update(data).eq('id', intentId);
      }
      if (skillsNeededIds != null || skillsOfferedIds != null) {
        if (skillsNeededIds != null) {
          await _client.from(Tables.intentSkills).delete().eq('intent_id', intentId).eq('direction', 'needed');
        }
        if (skillsOfferedIds != null) {
          await _client.from(Tables.intentSkills).delete().eq('intent_id', intentId).eq('direction', 'offered');
        }
        final skillRows = [
          for (final skillId in skillsNeededIds ?? const <String>[])
            {'intent_id': intentId, 'skill_id': skillId, 'direction': 'needed'},
          for (final skillId in skillsOfferedIds ?? const <String>[])
            {'intent_id': intentId, 'skill_id': skillId, 'direction': 'offered'},
        ];
        if (skillRows.isNotEmpty) {
          await _client.from(Tables.intentSkills).insert(skillRows);
        }
      }
      return await getIntent(intentId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> setStatus(String intentId, String status) async {
    try {
      await _client
          .from(Tables.intents)
          .update({'status': status}).eq('id', intentId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> renew(String intentId, DateTime newExpiresAt) async {
    try {
      await _client.from(Tables.intents).update({
        'expires_at': newExpiresAt.toIso8601String(),
        'status': 'active',
      }).eq('id', intentId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> deleteIntent(String intentId) async {
    try {
      await _client.from(Tables.intents).delete().eq('id', intentId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> refreshMatches(String intentId) async {
    try {
      // The edge function's own AI_RATIONALE_TIMEOUT_MS (8s) already bounds
      // its LLM call, but a client-side ceiling on top of that protects
      // against a hung request/slow network entirely independent of the
      // function's own logic — this is the "never hang on stage" guard.
      final response = await _client.functions
          .invoke('ai-match-intent', body: {'intent_id': intentId})
          .timeout(const Duration(seconds: 15));
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'] as String);
      }
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<MatchResult>> getCachedMatches(String intentId) async {
    try {
      final data = await _client
          .from(Tables.intentMatches)
          .select(_matchSelect)
          .eq('intent_id', intentId)
          .order('score', ascending: false);
      return (data as List)
          .map((e) => MatchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> refreshRecommendations(String intentId) async {
    try {
      final response = await _client.functions
          .invoke('get-network-recommendations', body: {'intent_id': intentId})
          .timeout(const Duration(seconds: 15));
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'] as String);
      }
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<IntentRecommendation>> getCachedRecommendations(String intentId) async {
    try {
      final data = await _client
          .from(Tables.intentRecommendations)
          .select()
          .eq('intent_id', intentId)
          .order('score', ascending: false);
      return (data as List)
          .map((e) => IntentRecommendation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
