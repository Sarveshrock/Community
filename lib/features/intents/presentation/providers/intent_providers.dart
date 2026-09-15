import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/skill.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../matching/domain/entities/intent_recommendation.dart';
import '../../../matching/domain/entities/match_result.dart';
import '../../data/repositories/intent_repository_impl.dart';
import '../../domain/entities/intent.dart';
import '../../domain/repositories/intent_repository.dart';

export '../../domain/entities/intent.dart';
export '../../../matching/domain/entities/intent_recommendation.dart';
export '../../../matching/domain/entities/match_result.dart';

final intentRepositoryProvider = Provider<IntentRepository>((ref) {
  return IntentRepositoryImpl(supabase);
});

final publicIntentsProvider = FutureProvider<List<UserIntent>>((ref) {
  return ref.watch(intentRepositoryProvider).listPublicIntents();
});

/// Client-side search/filter state for the discovery list — deliberately not
/// pushed down into a new repository/RPC signature: [listPublicIntents]
/// already returns everything a viewer is allowed to see (RLS-enforced), and
/// filtering that in memory avoids adding new query-param plumbing for what
/// is, per page, a small result set.
class IntentFilters {
  const IntentFilters({
    this.type,
    this.skill,
    this.experienceLevel,
    this.workMode,
    this.searchText = '',
  });

  final IntentType? type;
  final String? skill;
  final ExperienceLevel? experienceLevel;
  final String? workMode;
  final String searchText;

  bool get isActive =>
      type != null || skill != null || experienceLevel != null || workMode != null || searchText.trim().isNotEmpty;

  IntentFilters copyWith({
    IntentType? Function()? type,
    String? Function()? skill,
    ExperienceLevel? Function()? experienceLevel,
    String? Function()? workMode,
    String? searchText,
  }) {
    return IntentFilters(
      type: type != null ? type() : this.type,
      skill: skill != null ? skill() : this.skill,
      experienceLevel: experienceLevel != null ? experienceLevel() : this.experienceLevel,
      workMode: workMode != null ? workMode() : this.workMode,
      searchText: searchText ?? this.searchText,
    );
  }

  bool matches(UserIntent intent) {
    if (type != null && intent.intentType != type) return false;
    if (experienceLevel != null && intent.experienceLevel != experienceLevel) return false;
    if (workMode != null && intent.workMode != workMode) return false;
    if (skill != null) {
      final needle = skill!.toLowerCase();
      final hasSkill = intent.skillsNeeded.any((s) => s.toLowerCase() == needle) ||
          intent.skillsOffered.any((s) => s.toLowerCase() == needle);
      if (!hasSkill) return false;
    }
    final query = searchText.trim().toLowerCase();
    if (query.isNotEmpty) {
      final haystack = '${intent.title} ${intent.description ?? ''}'.toLowerCase();
      if (!haystack.contains(query)) return false;
    }
    return true;
  }
}

final intentFiltersProvider = StateProvider<IntentFilters>((ref) => const IntentFilters());

final filteredPublicIntentsProvider = Provider<AsyncValue<List<UserIntent>>>((ref) {
  final filters = ref.watch(intentFiltersProvider);
  return ref.watch(publicIntentsProvider).whenData(
        (intents) => intents.where(filters.matches).toList(),
      );
});

final myIntentsProvider = FutureProvider<List<UserIntent>>((ref) {
  return ref.watch(intentRepositoryProvider).myIntents();
});

final intentDetailProvider = FutureProvider.family<UserIntent, String>((ref, id) {
  return ref.watch(intentRepositoryProvider).getIntent(id);
});

final intentMatchesProvider =
    FutureProvider.family<List<MatchResult>, String>((ref, intentId) {
  return ref.watch(intentRepositoryProvider).getCachedMatches(intentId);
});

/// Cross-entity ("Because of this match") recommendations — communities,
/// events, projects, posts surfaced through the people [intentMatchesProvider]
/// already found. Populated by [IntentController.refreshRecommendations],
/// which only makes sense to call after matches already exist.
final intentRecommendationsProvider =
    FutureProvider.family<List<IntentRecommendation>, String>((ref, intentId) {
  return ref.watch(intentRepositoryProvider).getCachedRecommendations(intentId);
});

class IntentController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createIntent(
    Map<String, dynamic> data, {
    required List<String> skillsNeededIds,
    required List<String> skillsOfferedIds,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(intentRepositoryProvider).createIntent(
          data,
          skillsNeededIds: skillsNeededIds,
          skillsOfferedIds: skillsOfferedIds,
        ));
    state = result;
    if (!result.hasError) {
      ref.invalidate(myIntentsProvider);
      ref.invalidate(publicIntentsProvider);
    }
    return !result.hasError;
  }

  Future<bool> updateIntent(
    String intentId,
    Map<String, dynamic> data, {
    List<String>? skillsNeededIds,
    List<String>? skillsOfferedIds,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(intentRepositoryProvider).updateIntent(
          intentId,
          data,
          skillsNeededIds: skillsNeededIds,
          skillsOfferedIds: skillsOfferedIds,
        ));
    state = result;
    if (!result.hasError) {
      ref.invalidate(myIntentsProvider);
      ref.invalidate(publicIntentsProvider);
      ref.invalidate(intentDetailProvider(intentId));
    }
    return !result.hasError;
  }

  /// Convenience wrapper over [setStatus] — kept as its own method (rather
  /// than callers passing the raw 'fulfilled' string) so intent completion
  /// stays a named, discoverable action.
  Future<bool> markFulfilled(String intentId) => setStatus(intentId, 'fulfilled');

  Future<bool> setStatus(String intentId, String status) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(intentRepositoryProvider).setStatus(intentId, status));
    state = result;
    if (!result.hasError) {
      ref.invalidate(myIntentsProvider);
      ref.invalidate(intentDetailProvider(intentId));
    }
    return !result.hasError;
  }

  Future<bool> renew(String intentId, DateTime newExpiresAt) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(intentRepositoryProvider).renew(intentId, newExpiresAt));
    state = result;
    if (!result.hasError) {
      ref.invalidate(myIntentsProvider);
      ref.invalidate(intentDetailProvider(intentId));
    }
    return !result.hasError;
  }

  Future<bool> deleteIntent(String intentId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(intentRepositoryProvider).deleteIntent(intentId));
    state = result;
    if (!result.hasError) {
      ref.invalidate(myIntentsProvider);
      ref.invalidate(publicIntentsProvider);
    }
    return !result.hasError;
  }

  Future<bool> refreshMatches(String intentId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(intentRepositoryProvider).refreshMatches(intentId));
    state = result;
    if (!result.hasError) ref.invalidate(intentMatchesProvider(intentId));
    return !result.hasError;
  }

  Future<bool> refreshRecommendations(String intentId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(intentRepositoryProvider).refreshRecommendations(intentId));
    state = result;
    if (!result.hasError) ref.invalidate(intentRecommendationsProvider(intentId));
    return !result.hasError;
  }

  /// "Find Matches" is really one user action driving two server steps —
  /// get-network-recommendations reads the top rows refreshMatches just
  /// wrote, so it only makes sense to run second, never standalone. A
  /// recommendations failure is deliberately non-fatal: matches themselves
  /// (the P0 feature) still succeed and render even if the newer network
  /// layer errors or times out.
  Future<bool> findMatchesAndRecommendations(String intentId) async {
    final matchesOk = await refreshMatches(intentId);
    if (!matchesOk) return false;
    await refreshRecommendations(intentId);
    return true;
  }
}

final intentControllerProvider =
    AsyncNotifierProvider<IntentController, void>(IntentController.new);
