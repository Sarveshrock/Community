// Locks down the one thing this whole feature is about: the category chip
// ("who am I looking for?") and the All/Recommended tab ("how should they
// be surfaced?") are independent selectors that compose together, rather
// than one resetting or overriding the other. A `ProviderContainer` with a
// fake repository lets this be verified without rendering any widgets or
// touching Supabase.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/people/domain/repositories/people_repository.dart';
import 'package:community_app/features/people/presentation/providers/people_providers.dart';

class _FakePeopleRepository implements PeopleRepository {
  PeopleFilters? lastSearchFilters;
  String? lastRecommendationsUserType;
  int? lastRecommendationsMaxExperienceMonths;
  List<Map<String, dynamic>> recommendations = const [];

  @override
  Future<List<Profile>> search(PeopleFilters filters,
      {int limit = 20, int offset = 0}) async {
    lastSearchFilters = filters;
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> getAiRecommendations({
    int limit = 20,
    String? userType,
    int? maxExperienceMonths,
  }) async {
    lastRecommendationsUserType = userType;
    lastRecommendationsMaxExperienceMonths = maxExperienceMonths;
    return recommendations;
  }
}

void main() {
  late _FakePeopleRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = _FakePeopleRepository();
    container = ProviderContainer(
      overrides: [peopleRepositoryProvider.overrideWithValue(fake)],
    );
  });

  tearDown(() => container.dispose());

  test('a category chip narrows the All tab search by primary_user_type', () async {
    container.read(peopleCategoryProvider.notifier).state = PeopleCategory.developer;
    await container.read(peopleSearchResultsProvider.future);

    expect(fake.lastSearchFilters!.userType, 'developer');
    expect(fake.lastSearchFilters!.maxExperienceMonths, isNull);
  });

  test('Fresher narrows by experience, not by a fake user_type value', () async {
    container.read(peopleCategoryProvider.notifier).state = PeopleCategory.fresher;
    await container.read(peopleSearchResultsProvider.future);

    expect(fake.lastSearchFilters!.userType, isNull);
    expect(fake.lastSearchFilters!.maxExperienceMonths, 0);
  });

  test('All category applies no category narrowing at all', () async {
    container.read(peopleCategoryProvider.notifier).state = PeopleCategory.all;
    await container.read(peopleSearchResultsProvider.future);

    expect(fake.lastSearchFilters!.userType, isNull);
    expect(fake.lastSearchFilters!.maxExperienceMonths, isNull);
  });

  test('existing query/city filters survive a category change untouched', () async {
    container.read(peopleFiltersProvider.notifier).state =
        const PeopleFilters(query: 'flutter', city: 'Pune');
    container.read(peopleCategoryProvider.notifier).state = PeopleCategory.student;
    await container.read(peopleSearchResultsProvider.future);

    expect(fake.lastSearchFilters!.query, 'flutter');
    expect(fake.lastSearchFilters!.city, 'Pune');
    expect(fake.lastSearchFilters!.userType, 'student');
  });

  test('switching category again (Developer -> Professional) keeps composing correctly, '
      'never carrying over the previous category', () async {
    container.read(peopleCategoryProvider.notifier).state = PeopleCategory.developer;
    await container.read(peopleSearchResultsProvider.future);
    expect(fake.lastSearchFilters!.userType, 'developer');

    container.read(peopleCategoryProvider.notifier).state = PeopleCategory.professional;
    container.invalidate(peopleSearchResultsProvider);
    await container.read(peopleSearchResultsProvider.future);
    expect(fake.lastSearchFilters!.userType, 'professional');
  });

  test('Recommended pool is scoped server-side by the same selected category', () async {
    container.read(peopleCategoryProvider.notifier).state = PeopleCategory.jobSeeker;
    await container.read(aiRecommendedPeopleProvider.future);

    expect(fake.lastRecommendationsUserType, 'job_seeker');
    expect(fake.lastRecommendationsMaxExperienceMonths, isNull);
  });

  test('Recommended + Fresher requests the experience-based pool, not a user_type', () async {
    container.read(peopleCategoryProvider.notifier).state = PeopleCategory.fresher;
    await container.read(aiRecommendedPeopleProvider.future);

    expect(fake.lastRecommendationsUserType, isNull);
    expect(fake.lastRecommendationsMaxExperienceMonths, 0);
  });

  test('search composes with Recommended by filtering the already-scored pool client-side', () async {
    fake.recommendations = [
      {'candidate_id': '1', 'full_name': 'Ada Flutter Dev', 'score': 90},
      {'candidate_id': '2', 'full_name': 'Bob Backend', 'current_role': 'Backend Engineer', 'score': 80},
    ];
    container.read(peopleFiltersProvider.notifier).state = const PeopleFilters(query: 'flutter');

    final result = await container.read(aiRecommendedPeopleProvider.future);

    expect(result, hasLength(1));
    expect(result.first['candidate_id'], '1');
  });

  test('an empty/unset search query returns every recommendation unfiltered', () async {
    fake.recommendations = [
      {'candidate_id': '1', 'full_name': 'Ada', 'score': 90},
      {'candidate_id': '2', 'full_name': 'Bob', 'score': 80},
    ];

    final result = await container.read(aiRecommendedPeopleProvider.future);

    expect(result, hasLength(2));
  });
}
