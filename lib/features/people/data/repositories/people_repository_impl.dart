import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/repositories/people_repository.dart';

class PeopleRepositoryImpl implements PeopleRepository {
  PeopleRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Profile>> search(PeopleFilters filters,
      {int limit = 20, int offset = 0}) async {
    try {
      final myId = _client.auth.currentUser?.id;
      var query = _client
          .from(Tables.profiles)
          .select(
            '*, profile_skills(experience_level, years_experience, skills(id, name, category)), profile_interests(interests(id, name))',
          )
          .eq('professional_discoverable', true);

      if (myId != null) {
        query = query.neq('id', myId);
        // profiles_select_discoverable RLS has no blocking exclusion built
        // in (it only checks professional_discoverable) — `blocks_select`
        // only lets the caller read blocks *they* created, so this can only
        // ever hide people the caller has blocked, not people who blocked
        // the caller. That asymmetric case is already handled correctly on
        // the Recommended path, which goes through the service-role edge
        // function instead.
        final blockedIds = await _blockedByMe(myId);
        if (blockedIds.isNotEmpty) {
          query = query.not('id', 'in', '(${blockedIds.join(',')})');
        }
      }
      if (filters.city != null && filters.city!.isNotEmpty) {
        query = query.ilike('city', '%${filters.city}%');
      }
      if (filters.userType != null) {
        query = query.eq('primary_user_type', filters.userType!);
      }
      if (filters.minExperienceMonths != null) {
        query = query.gte(
            'total_it_experience_months', filters.minExperienceMonths!);
      }
      if (filters.maxExperienceMonths != null) {
        query = query.lte(
            'total_it_experience_months', filters.maxExperienceMonths!);
      }
      if (filters.query != null && filters.query!.isNotEmpty) {
        query = query.or(
            'full_name.ilike.%${filters.query}%,current_role.ilike.%${filters.query}%,current_company.ilike.%${filters.query}%');
      }

      final data = await query
          .order('updated_at', ascending: false)
          .range(offset, offset + limit - 1);

      var profiles = (data as List)
          .map((e) => Profile.fromJson(e as Map<String, dynamic>))
          .toList();

      if (filters.skillId != null) {
        profiles = profiles
            .where((p) => p.skills.any((s) => s.skill.id == filters.skillId))
            .toList();
      }

      return profiles;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  Future<List<String>> _blockedByMe(String myId) async {
    final rows = await _client
        .from(Tables.blocks)
        .select('blocked_id')
        .eq('blocker_id', myId);
    return (rows as List).map((r) => r['blocked_id'] as String).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAiRecommendations({
    int limit = 20,
    String? userType,
    int? maxExperienceMonths,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'ai-match-people',
        body: {
          'limit': limit,
          if (userType != null) 'userType': userType,
          if (maxExperienceMonths != null)
            'maxExperienceMonths': maxExperienceMonths,
        },
      );
      final data = response.data;
      if (data is Map && data['recommendations'] is List) {
        return (data['recommendations'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
