import '../../../matching/domain/entities/intent_recommendation.dart';
import '../../../matching/domain/entities/match_result.dart';
import '../entities/intent.dart';

abstract class IntentRepository {
  Future<List<UserIntent>> listPublicIntents({int limit = 20, int offset = 0});
  Future<List<UserIntent>> myIntents();
  Future<UserIntent> getIntent(String id);

  Future<UserIntent> createIntent(
    Map<String, dynamic> data, {
    required List<String> skillsNeededIds,
    required List<String> skillsOfferedIds,
  });

  /// Updates an existing intent's own row. [skillsNeededIds]/[skillsOfferedIds]
  /// are left untouched when null; passing either (even an empty list)
  /// replaces that direction's skill rows entirely.
  Future<UserIntent> updateIntent(
    String intentId,
    Map<String, dynamic> data, {
    List<String>? skillsNeededIds,
    List<String>? skillsOfferedIds,
  });

  Future<void> setStatus(String intentId, String status);
  Future<void> renew(String intentId, DateTime newExpiresAt);
  Future<void> deleteIntent(String intentId);

  /// Runs the matching engine for [intentId] and caches the results
  /// server-side (intent_matches) — call [getCachedMatches] afterwards to
  /// read them back.
  Future<void> refreshMatches(String intentId);
  Future<List<MatchResult>> getCachedMatches(String intentId);

  /// Runs the cross-entity recommendation engine (communities/events/
  /// projects/posts surfaced through already-computed top matches — see
  /// get-network-recommendations) and caches the results server-side
  /// (intent_recommendations). Call [getCachedRecommendations] afterwards
  /// to read them back. Intended to run after [refreshMatches] has already
  /// populated intent_matches for this intent, not standalone.
  Future<void> refreshRecommendations(String intentId);
  Future<List<IntentRecommendation>> getCachedRecommendations(String intentId);
}
