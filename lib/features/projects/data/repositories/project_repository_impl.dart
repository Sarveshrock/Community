import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _select = '*, project_required_skills(skills(name))';

  @override
  Future<List<Project>> listProjects({int limit = 20, int offset = 0}) async {
    try {
      final data = await _client
          .from(Tables.projects)
          .select(_select)
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => Project.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Project> getProject(String id) async {
    try {
      final data = await _client
          .from(Tables.projects)
          .select(_select)
          .eq('id', id)
          .single();
      return Project.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Project> createProject(
      Map<String, dynamic> data, List<String> skillIds) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client
          .from(Tables.projects)
          .insert({...data, 'owner_id': myId})
          .select()
          .single();
      final projectId = inserted['id'] as String;
      if (skillIds.isNotEmpty) {
        await _client.from('project_required_skills').insert([
          for (final skillId in skillIds)
            {'project_id': projectId, 'skill_id': skillId},
        ]);
      }
      return await getProject(projectId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<bool> hasExpressedInterest(String projectId, String profileId) async {
    try {
      final data = await _client
          .from(Tables.projectInterests)
          .select('id')
          .eq('project_id', projectId)
          .eq('profile_id', profileId)
          .maybeSingle();
      return data != null;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> expressInterest(String projectId, String? message) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.projectInterests).insert({
        'project_id': projectId,
        'profile_id': myId,
        'message': message,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getInterestsForProject(
      String projectId) async {
    try {
      final data = await _client
          .from(Tables.projectInterests)
          .select('*, profiles(full_name, avatar_url, current_role)')
          .eq('project_id', projectId)
          .order('created_at', ascending: false);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> respondToInterest(String interestId,
      {required bool accept}) async {
    try {
      await _client.from(Tables.projectInterests).update(
          {'status': accept ? 'accepted' : 'rejected'}).eq('id', interestId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
