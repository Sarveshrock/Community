import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/models/interest.dart';
import '../../../../core/models/skill.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/education.dart';
import '../../domain/entities/experience.dart';
import '../../domain/entities/optional_proof.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

export '../../../../core/models/interest.dart';
export '../../../../core/models/skill.dart';
export '../../domain/entities/education.dart';
export '../../domain/entities/experience.dart';
export '../../domain/entities/optional_proof.dart';
export '../../domain/entities/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(supabase);
});

/// The signed-in user's own profile. Depends on [authStateProvider] so it
/// automatically resolves to null/refreshes across sign-in and sign-out.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).getProfile(user.id);
});

/// Any profile by id (people discovery, connection cards, chat headers...).
final profileByIdProvider =
    FutureProvider.family<Profile, String>((ref, id) async {
  return ref.watch(profileRepositoryProvider).getProfile(id);
});

/// Resolves a bare `avatars` storage path (e.g. `<profileId>/avatar.jpg`) to
/// a short-lived signed URL — the `avatars` bucket is private
/// (0049_profile_photo_privacy.sql), so this is also where photo-visibility
/// is actually enforced: Storage RLS denies the request for an unauthorized
/// viewer, which surfaces here as an error, not a decision this provider
/// makes itself. `UserAvatar` (the single avatar-rendering widget used
/// throughout the app) is the only intended caller.
final avatarSignedUrlProvider =
    FutureProvider.family<String, String>((ref, storagePath) {
  return ref.watch(profileRepositoryProvider).getAvatarSignedUrl(storagePath);
});

final allSkillsProvider = FutureProvider<List<Skill>>((ref) {
  return ref.watch(profileRepositoryProvider).allSkills();
});

final allInterestsProvider = FutureProvider<List<Interest>>((ref) {
  return ref.watch(profileRepositoryProvider).allInterests();
});

final myExperiencesProvider = FutureProvider<List<Experience>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getExperiences(user.id);
});

final myEducationProvider = FutureProvider<List<Education>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getEducation(user.id);
});

final myOptionalProofsProvider =
    FutureProvider<List<OptionalProof>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getOptionalProofs(user.id);
});

/// Mutations for the profile feature. All methods refresh [myProfileProvider]
/// on success so every screen observing "my profile" stays in sync.
class ProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> updateProfile(Map<String, dynamic> changes) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateProfile(user.id, changes),
    );
    state = result;
    if (!result.hasError) ref.invalidate(myProfileProvider);
    return !result.hasError;
  }

  Future<bool> completeOnboarding({
    required Map<String, dynamic> profileChanges,
    required List<(String, ExperienceLevel)> skills,
    required List<String> interestIds,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;
    state = const AsyncLoading();
    final repo = ref.read(profileRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.updateProfile(user.id, profileChanges);
      await repo.setSkills(user.id, skills);
      await repo.setInterests(user.id, interestIds);
      await repo.markProfileCompleted(user.id);
    });
    state = result;
    if (!result.hasError) {
      ref.invalidate(myProfileProvider);
      ref.read(analyticsServiceProvider).log(AnalyticsEvents.profileCompleted);
    }
    return !result.hasError;
  }

  Future<bool> addExperience(Experience experience) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(profileRepositoryProvider)
          .addExperience(user.id, experience),
    );
    state = result;
    if (!result.hasError) ref.invalidate(myExperiencesProvider);
    return !result.hasError;
  }

  Future<bool> deleteExperience(String experienceId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).deleteExperience(experienceId),
    );
    state = result;
    if (!result.hasError) ref.invalidate(myExperiencesProvider);
    return !result.hasError;
  }

  /// Adds skills the caller doesn't already have, on top of whatever
  /// skills onboarding (or a previous call here) already set — [setSkills]
  /// itself fully replaces the row set, so this reads the current profile
  /// first and merges rather than dropping existing skills. New skills
  /// default to intermediate; existing ones keep their recorded level.
  Future<bool> addSkillIds(List<String> skillIds) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;
    final profile = ref.read(myProfileProvider).valueOrNull;
    final existing = <(String, ExperienceLevel)>[
      for (final s in profile?.skills ?? const []) (s.skill.id, s.level)
    ];
    final existingIds = existing.map((e) => e.$1).toSet();
    final merged = <(String, ExperienceLevel)>[
      ...existing,
      for (final id in skillIds)
        if (!existingIds.contains(id)) (id, ExperienceLevel.intermediate),
    ];
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).setSkills(user.id, merged),
    );
    state = result;
    if (!result.hasError) ref.invalidate(myProfileProvider);
    return !result.hasError;
  }

  /// Same idea as [addSkillIds], for interests.
  Future<bool> addInterestIds(List<String> interestIds) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;
    final profile = ref.read(myProfileProvider).valueOrNull;
    final merged = <String>{
      for (final i in profile?.interests ?? const []) i.id,
      ...interestIds,
    }.toList();
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).setInterests(user.id, merged),
    );
    state = result;
    if (!result.hasError) ref.invalidate(myProfileProvider);
    return !result.hasError;
  }

  Future<bool> addOptionalProof(OptionalProof proof) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () =>
          ref.read(profileRepositoryProvider).addOptionalProof(user.id, proof),
    );
    state = result;
    if (!result.hasError) ref.invalidate(myOptionalProofsProvider);
    return !result.hasError;
  }

  Future<bool> deleteOptionalProof(String proofId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).deleteOptionalProof(proofId),
    );
    state = result;
    if (!result.hasError) ref.invalidate(myOptionalProofsProvider);
    return !result.hasError;
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, void>(ProfileController.new);
