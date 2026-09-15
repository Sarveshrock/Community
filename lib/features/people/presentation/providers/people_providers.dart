import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_config.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../data/repositories/people_repository_impl.dart';
import '../../domain/repositories/people_repository.dart';

export '../../../profile/domain/entities/profile.dart';
export '../../domain/repositories/people_repository.dart' show PeopleFilters;

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) {
  return PeopleRepositoryImpl(supabase);
});

/// "Who am I looking for?" — independent of [PeopleMode] ("How should they
/// be surfaced?"). `fresher` isn't a real `primary_user_type` value in the
/// database (see `0002_enums.sql`); it's identified by ~0 months of IT
/// experience instead, via [PeopleCategoryX.maxExperienceMonths].
enum PeopleCategory { all, developer, professional, student, jobSeeker, fresher }

extension PeopleCategoryX on PeopleCategory {
  String get label => switch (this) {
        PeopleCategory.all => 'All',
        PeopleCategory.developer => 'Developer',
        PeopleCategory.professional => 'Professional',
        PeopleCategory.student => 'Student',
        PeopleCategory.jobSeeker => 'Job Seeker',
        PeopleCategory.fresher => 'Fresher',
      };

  /// The `primary_user_type` enum value this category filters to, or null
  /// when the category isn't backed by that column (`all`, `fresher`).
  String? get userTypeValue => switch (this) {
        PeopleCategory.developer => 'developer',
        PeopleCategory.professional => 'professional',
        PeopleCategory.student => 'student',
        PeopleCategory.jobSeeker => 'job_seeker',
        _ => null,
      };

  int? get maxExperienceMonths => this == PeopleCategory.fresher ? 0 : null;
}

/// "How should these people be surfaced?" (All vs. Recommended) —
/// independent of [PeopleCategory]. The screen's `TabController` is already
/// the source of truth for which mode is showing (unchanged from before
/// this feature); nothing outside the screen needs to react to it, so
/// there's no separate provider here — two sources of truth for the same
/// selection is exactly the kind of thing spec section 34's "don't reset on
/// switch" requirement would then have to keep in sync by hand.
///
/// Query/city set via the existing filter sheet. Deliberately kept separate
/// from [peopleCategoryProvider] so neither selector needs to know about
/// the other — they're composed together only at the point each list is
/// actually fetched, below.
final peopleFiltersProvider =
    StateProvider<PeopleFilters>((ref) => const PeopleFilters());

final peopleCategoryProvider =
    StateProvider<PeopleCategory>((ref) => PeopleCategory.all);

/// The filters actually sent to the repository for the "All" tab: the
/// filter-sheet's query/city plus whatever category chip is selected.
final _effectivePeopleFiltersProvider = Provider<PeopleFilters>((ref) {
  final base = ref.watch(peopleFiltersProvider);
  final category = ref.watch(peopleCategoryProvider);
  return base.copyWith(
    userType: category.userTypeValue,
    maxExperienceMonths: category.maxExperienceMonths,
  );
});

final peopleSearchResultsProvider = FutureProvider<List<Profile>>((ref) async {
  final filters = ref.watch(_effectivePeopleFiltersProvider);
  return ref.watch(peopleRepositoryProvider).search(filters);
});

/// Recommendations, scoped to the selected category server-side (the edge
/// function narrows its candidate pool before scoring — see
/// `ai-match-people`) and then to the filter sheet's free-text query
/// client-side. The query is applied here rather than server-side because
/// the recommendation list is already small (capped well under 50) and the
/// edge function has no query param today; adding one would duplicate the
/// exact `full_name`/`current_role`/`current_company` matching
/// `PeopleRepositoryImpl.search` already does server-side for the All tab.
final aiRecommendedPeopleProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final category = ref.watch(peopleCategoryProvider);
  final query = ref.watch(peopleFiltersProvider).query?.trim().toLowerCase();

  final recommendations =
      await ref.watch(peopleRepositoryProvider).getAiRecommendations(
            userType: category.userTypeValue,
            maxExperienceMonths: category.maxExperienceMonths,
          );

  if (query == null || query.isEmpty) return recommendations;
  return recommendations.where((r) {
    final haystack = [
      r['full_name'],
      r['current_role'],
      r['current_company'],
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(query);
  }).toList();
});
