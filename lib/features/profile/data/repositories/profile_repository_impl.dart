import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/models/interest.dart';
import '../../../../core/models/skill.dart';
import '../../domain/entities/education.dart';
import '../../domain/entities/experience.dart';
import '../../domain/entities/optional_proof.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _profileSelect =
      '*, profile_skills(experience_level, years_experience, skills(id, name, category)), profile_interests(interests(id, name))';

  @override
  Future<Profile> getProfile(String profileId) async {
    try {
      final data = await _client
          .from(Tables.profiles)
          .select(_profileSelect)
          .eq('id', profileId)
          .single();
      return Profile.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> updateProfile(
      String profileId, Map<String, dynamic> changes) async {
    try {
      await _client.from(Tables.profiles).update(changes).eq('id', profileId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> markProfileCompleted(String profileId) async {
    await updateProfile(profileId, {'profile_completed': true});
  }

  @override
  Future<void> setSkills(
      String profileId, List<(String, ExperienceLevel)> skills) async {
    try {
      await _client
          .from(Tables.profileSkills)
          .delete()
          .eq('profile_id', profileId);
      if (skills.isEmpty) return;
      await _client.from(Tables.profileSkills).insert([
        for (final (skillId, level) in skills)
          {
            'profile_id': profileId,
            'skill_id': skillId,
            'experience_level': level.value
          },
      ]);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> setInterests(String profileId, List<String> interestIds) async {
    try {
      await _client
          .from(Tables.profileInterests)
          .delete()
          .eq('profile_id', profileId);
      if (interestIds.isEmpty) return;
      await _client.from(Tables.profileInterests).insert([
        for (final interestId in interestIds)
          {'profile_id': profileId, 'interest_id': interestId},
      ]);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<Experience>> getExperiences(String profileId) async {
    try {
      final data = await _client
          .from(Tables.experiences)
          .select()
          .eq('profile_id', profileId)
          .order('start_date', ascending: false);
      return (data as List)
          .map((e) => Experience.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Experience> addExperience(
      String profileId, Experience experience) async {
    try {
      final data = await _client
          .from(Tables.experiences)
          .insert(experience.toInsertJson(profileId))
          .select()
          .single();
      return Experience.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> updateExperience(
      String experienceId, Map<String, dynamic> changes) async {
    try {
      await _client
          .from(Tables.experiences)
          .update(changes)
          .eq('id', experienceId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> deleteExperience(String experienceId) async {
    try {
      await _client.from(Tables.experiences).delete().eq('id', experienceId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<Education>> getEducation(String profileId) async {
    try {
      final data = await _client
          .from(Tables.education)
          .select()
          .eq('profile_id', profileId)
          .order('start_year', ascending: false);
      return (data as List)
          .map((e) => Education.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Education> addEducation(String profileId, Education education) async {
    try {
      final data = await _client
          .from(Tables.education)
          .insert(education.toInsertJson(profileId))
          .select()
          .single();
      return Education.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> deleteEducation(String educationId) async {
    try {
      await _client.from(Tables.education).delete().eq('id', educationId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<OptionalProof>> getOptionalProofs(String profileId) async {
    try {
      final data = await _client
          .from(Tables.optionalProofs)
          .select()
          .eq('profile_id', profileId);
      return (data as List)
          .map((e) => OptionalProof.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<OptionalProof> addOptionalProof(
      String profileId, OptionalProof proof) async {
    try {
      final data = await _client
          .from(Tables.optionalProofs)
          .insert(proof.toInsertJson(profileId))
          .select()
          .single();
      return OptionalProof.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> deleteOptionalProof(String proofId) async {
    try {
      await _client.from(Tables.optionalProofs).delete().eq('id', proofId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<Skill>> searchSkills(String query) async {
    try {
      final data = await _client
          .from(Tables.skills)
          .select()
          .ilike('name', '%$query%')
          .limit(20);
      return (data as List)
          .map((e) => Skill.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<Skill>> allSkills() async {
    try {
      final data =
          await _client.from(Tables.skills).select().order('name').limit(500);
      return (data as List)
          .map((e) => Skill.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<Interest>> allInterests() async {
    try {
      final data = await _client
          .from(Tables.interests)
          .select()
          .order('name')
          .limit(500);
      return (data as List)
          .map((e) => Interest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> uploadAvatar(
      String profileId, List<int> bytes, String fileExt) async {
    try {
      final path = '$profileId/avatar.$fileExt';
      await _client.storage.from(StorageBuckets.avatars).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: true),
          );
      // The `avatars` bucket is private (0049_profile_photo_privacy.sql) —
      // a permanent public URL would no longer resolve, and would bypass
      // photo-visibility enforcement anyway. Store the bare path; callers
      // resolve a short-lived signed URL on demand (see
      // `avatarSignedUrlProvider`), the same pattern `resumes` and
      // `chat-attachments` already use.
      return path;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> getAvatarSignedUrl(String storagePath) async {
    try {
      return await _client.storage
          .from(StorageBuckets.avatars)
          .createSignedUrl(storagePath, 3600);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
