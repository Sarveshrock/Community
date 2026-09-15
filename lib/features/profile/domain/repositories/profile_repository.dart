import '../../../../core/models/interest.dart';
import '../../../../core/models/skill.dart';
import '../entities/education.dart';
import '../entities/experience.dart';
import '../entities/optional_proof.dart';
import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile> getProfile(String profileId);

  Future<void> updateProfile(String profileId, Map<String, dynamic> changes);

  Future<void> markProfileCompleted(String profileId);

  Future<void> setSkills(
      String profileId, List<(String skillId, ExperienceLevel level)> skills);

  Future<void> setInterests(String profileId, List<String> interestIds);

  Future<List<Experience>> getExperiences(String profileId);
  Future<Experience> addExperience(String profileId, Experience experience);
  Future<void> updateExperience(
      String experienceId, Map<String, dynamic> changes);
  Future<void> deleteExperience(String experienceId);

  Future<List<Education>> getEducation(String profileId);
  Future<Education> addEducation(String profileId, Education education);
  Future<void> deleteEducation(String educationId);

  Future<List<OptionalProof>> getOptionalProofs(String profileId);
  Future<OptionalProof> addOptionalProof(String profileId, OptionalProof proof);
  Future<void> deleteOptionalProof(String proofId);

  Future<List<Skill>> searchSkills(String query);
  Future<List<Skill>> allSkills();
  Future<List<Interest>> allInterests();

  /// Returns the storage *path* (not a public URL — the `avatars` bucket is
  /// private); resolve a displayable URL via [getAvatarSignedUrl].
  Future<String> uploadAvatar(
      String profileId, List<int> bytes, String fileExt);

  /// Resolves a bare avatar storage path to a short-lived signed URL.
  /// Storage RLS (`avatars_read_if_authorized`, 0049) is what actually
  /// enforces photo-visibility here — this call simply fails for an
  /// unauthorized viewer, it doesn't decide anything itself.
  Future<String> getAvatarSignedUrl(String storagePath);
}
