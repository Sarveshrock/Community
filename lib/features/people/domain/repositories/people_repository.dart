import '../../../profile/domain/entities/profile.dart';

class PeopleFilters {
  const PeopleFilters({
    this.query,
    this.city,
    this.skillId,
    this.minExperienceMonths,
    this.maxExperienceMonths,
    this.userType,
  });

  final String? query;
  final String? city;
  final String? skillId;
  final int? minExperienceMonths;

  /// Upper bound on `total_it_experience_months` — backs the "Fresher"
  /// category (spec: freshers aren't a `user_type` enum value in the
  /// database, they're identified by having ~0 months of experience
  /// regardless of their actual user type).
  final int? maxExperienceMonths;
  final String? userType;

  bool get isEmpty =>
      query == null &&
      city == null &&
      skillId == null &&
      minExperienceMonths == null &&
      maxExperienceMonths == null &&
      userType == null;

  /// Layers the People screen's category selection on top of whatever the
  /// user has set via the filter sheet (query/city), without the two
  /// pieces of state needing to know about each other.
  PeopleFilters copyWith({
    String? query,
    String? city,
    String? skillId,
    int? minExperienceMonths,
    int? maxExperienceMonths,
    String? userType,
  }) {
    return PeopleFilters(
      query: query ?? this.query,
      city: city ?? this.city,
      skillId: skillId ?? this.skillId,
      minExperienceMonths: minExperienceMonths ?? this.minExperienceMonths,
      maxExperienceMonths: maxExperienceMonths ?? this.maxExperienceMonths,
      userType: userType ?? this.userType,
    );
  }
}

abstract class PeopleRepository {
  Future<List<Profile>> search(PeopleFilters filters,
      {int limit = 20, int offset = 0});

  /// Calls the ai-match-people Edge Function for deterministic + optional
  /// semantic recommendations (spec sections 42/43). Never computed on
  /// device — the client only renders what the server returns.
  /// [userType]/[maxExperienceMonths] scope the *candidate pool itself*
  /// (see the edge function) rather than filtering results after scoring,
  /// so a match score is always computed within the selected category.
  Future<List<Map<String, dynamic>>> getAiRecommendations({
    int limit = 20,
    String? userType,
    int? maxExperienceMonths,
  });
}
