import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/repositories/hackathon_repository.dart';

class HackathonRepositoryImpl implements HackathonRepository {
  HackathonRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _teamSelect =
      '*, profiles!hackathon_team_requirements_creator_id_fkey(full_name, avatar_url), '
      'hackathon_team_members(profile_id, joined_at, profiles(full_name, avatar_url, current_role, current_company)), '
      'hackathon_team_required_skills(skills(name)), '
      'hackathon_team_skills_have(skills(name)), '
      'hackathon_team_role_requirements(*, hackathon_team_role_required_skills(skills(name)))';

  @override
  Future<List<Hackathon>> listHackathons(
      {int limit = 20, int offset = 0}) async {
    try {
      final data = await _client
          .from(Tables.hackathons)
          .select('*, hackathon_team_requirements(id)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => Hackathon.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Hackathon> getHackathon(String id) async {
    try {
      final data = await _client
          .from(Tables.hackathons)
          .select('*, hackathon_team_requirements(id)')
          .eq('id', id)
          .single();
      return Hackathon.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<TeamRequirement> getTeamRequirement(String teamRequirementId) async {
    try {
      final data = await _client
          .from(Tables.hackathonTeamRequirements)
          .select(_teamSelect)
          .eq('id', teamRequirementId)
          .single();
      return TeamRequirement.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> getOrCreateHackathon(String name,
      {DateTime? eventDate}) async {
    try {
      final id = await _client.rpc(
        'get_or_create_hackathon',
        params: {
          'p_name': name,
          'p_event_date': eventDate == null ? null : _dateOnly(eventDate),
        },
      );
      return id as String;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  String _dateOnly(DateTime d) => d.toIso8601String().split('T').first;

  @override
  Future<List<TeamRequirement>> listTeamRequirements(String hackathonId) async {
    try {
      final data = await _client
          .from(Tables.hackathonTeamRequirements)
          .select(_teamSelect)
          .eq('hackathon_id', hackathonId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => TeamRequirement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<TeamRequirement> createTeamRequirement(
    Map<String, dynamic> data,
    List<String> skillIds, {
    List<String> skillsHaveIds = const [],
    List<TeamRoleRequirement> roles = const [],
  }) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client
          .from(Tables.hackathonTeamRequirements)
          .insert({...data, 'creator_id': myId})
          .select()
          .single();
      final requirementId = inserted['id'] as String;
      if (skillIds.isNotEmpty) {
        await _client.from(Tables.hackathonTeamRequiredSkills).insert([
          for (final skillId in skillIds)
            {'team_requirement_id': requirementId, 'skill_id': skillId},
        ]);
      }
      if (skillsHaveIds.isNotEmpty) {
        await _client.from(Tables.hackathonTeamSkillsHave).insert([
          for (final skillId in skillsHaveIds)
            {'team_requirement_id': requirementId, 'skill_id': skillId},
        ]);
      }
      if (roles.isNotEmpty) {
        await _insertRoles(requirementId, roles);
      }
      // The creator counts as the team's first member.
      await _client.from(Tables.hackathonTeamMembers).insert({
        'team_requirement_id': requirementId,
        'profile_id': myId,
      });
      // Every team gets a private group chat from the moment it exists
      // (spec section 4) — the creator is its first member automatically.
      await _client.rpc('create_team_conversation',
          params: {'p_team_requirement_id': requirementId});
      final full = await _client
          .from(Tables.hackathonTeamRequirements)
          .select(_teamSelect)
          .eq('id', requirementId)
          .single();
      return TeamRequirement.fromJson(full);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  /// Inserts each role, then its skills — a role needs its own id before
  /// `hackathon_team_role_required_skills` rows can reference it.
  Future<void> _insertRoles(String teamRequirementId, List<TeamRoleRequirement> roles) async {
    for (final role in roles) {
      final insertedRole = await _client
          .from(Tables.hackathonTeamRoleRequirements)
          .insert(role.toInsertJson(teamRequirementId))
          .select('id')
          .single();
      final roleId = insertedRole['id'] as String;
      if (role.skillNames.isNotEmpty) {
        final skillIds = await _resolveSkillIdsByName(role.skillNames);
        if (skillIds.isNotEmpty) {
          await _client.from(Tables.hackathonTeamRoleRequiredSkills).insert([
            for (final skillId in skillIds) {'role_requirement_id': roleId, 'skill_id': skillId},
          ]);
        }
      }
    }
  }

  Future<List<String>> _resolveSkillIdsByName(List<String> names) async {
    final data = await _client.from(Tables.skills).select('id, name').inFilter('name', names);
    return (data as List).map((e) => e['id'] as String).toList();
  }

  @override
  Future<void> updateTeamRequirement(
    String teamRequirementId,
    Map<String, dynamic> data, {
    List<String>? skillIds,
    List<String>? skillsHaveIds,
    List<TeamRoleRequirement>? roles,
  }) async {
    try {
      if (data.isNotEmpty) {
        await _client.from(Tables.hackathonTeamRequirements).update(data).eq('id', teamRequirementId);
      }
      if (skillIds != null) {
        await _client.from(Tables.hackathonTeamRequiredSkills).delete().eq('team_requirement_id', teamRequirementId);
        if (skillIds.isNotEmpty) {
          await _client.from(Tables.hackathonTeamRequiredSkills).insert([
            for (final skillId in skillIds) {'team_requirement_id': teamRequirementId, 'skill_id': skillId},
          ]);
        }
      }
      if (skillsHaveIds != null) {
        await _client.from(Tables.hackathonTeamSkillsHave).delete().eq('team_requirement_id', teamRequirementId);
        if (skillsHaveIds.isNotEmpty) {
          await _client.from(Tables.hackathonTeamSkillsHave).insert([
            for (final skillId in skillsHaveIds) {'team_requirement_id': teamRequirementId, 'skill_id': skillId},
          ]);
        }
      }
      if (roles != null) {
        // Deleting the parent role rows cascades into
        // hackathon_team_role_required_skills automatically.
        await _client.from(Tables.hackathonTeamRoleRequirements).delete().eq('team_requirement_id', teamRequirementId);
        if (roles.isNotEmpty) {
          await _insertRoles(teamRequirementId, roles);
        }
      }
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> removeMember(String teamRequirementId, String profileId) async {
    try {
      await _client.rpc('remove_team_member', params: {
        'p_team_requirement_id': teamRequirementId,
        'p_profile_id': profileId,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String?> myTeamIdForHackathon(String hackathonId) async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return null;
      final result = await _client.rpc(
        'hackathon_team_of',
        params: {'p_profile_id': myId, 'p_hackathon_id': hackathonId},
      );
      return result as String?;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> sendTeamInvitation(
      {required String teamRequirementId,
      required String receiverId,
      String? message}) async {
    try {
      await _client.rpc('send_team_invitation', params: {
        'p_team_requirement_id': teamRequirementId,
        'p_receiver_id': receiverId,
        'p_message': message,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMyTeamInvitations(
      String profileId) async {
    try {
      final data = await _client
          .from(Tables.teamInvitations)
          .select('*, hackathon_team_requirements(team_name, hackathon_id)')
          .eq('receiver_id', profileId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> respondToInvitation(String invitationId,
      {required bool accept}) async {
    try {
      await _client.rpc('respond_to_team_invitation', params: {
        'p_invitation_id': invitationId,
        'p_accept': accept,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> requestToJoinTeam(String teamRequirementId,
      {String? message}) async {
    try {
      final id = await _client.rpc('request_to_join_team', params: {
        'p_team_requirement_id': teamRequirementId,
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
      await _client
          .rpc('cancel_join_request', params: {'p_request_id': requestId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> respondToJoinRequest(String requestId,
      {required bool accept}) async {
    try {
      await _client.rpc('respond_to_join_request', params: {
        'p_request_id': requestId,
        'p_accept': accept,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Set<String>> myPendingJoinRequestTeamIds(String hackathonId) async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return {};
      final data = await _client
          .from(Tables.hackathonTeamJoinRequests)
          .select(
              'team_requirement_id, hackathon_team_requirements!inner(hackathon_id)')
          .eq('requester_id', myId)
          .eq('status', 'pending')
          .eq('hackathon_team_requirements.hackathon_id', hackathonId);
      return (data as List)
          .map((e) => e['team_requirement_id'] as String)
          .toSet();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> leaveTeam(String teamRequirementId) async {
    try {
      await _client.rpc('leave_team',
          params: {'p_team_requirement_id': teamRequirementId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> deleteTeam(String teamRequirementId) async {
    try {
      await _client.rpc('delete_team_requirement',
          params: {'p_team_requirement_id': teamRequirementId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String?> getTeamConversationId(String teamRequirementId) async {
    try {
      final data = await _client
          .from(Tables.conversations)
          .select('id')
          .eq('team_requirement_id', teamRequirementId)
          .maybeSingle();
      return data?['id'] as String?;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
