import 'entities/intent.dart';

/// A simple, deterministic reciprocal-match score between two intents —
/// spec's "you need what they offer, and they need what you offer" example.
/// Distinct from the existing `ai-match-intent` edge function (which scores
/// *candidates* against one intent using AI); this is a pure, local
/// function with no network/AI call, intended for a quick "you and this
/// other intent complement each other" signal shown right on a card.
class IntentMatchResult {
  const IntentMatchResult({required this.percent, required this.theyOfferYouNeed, required this.youOfferTheyNeed});

  /// 0-100.
  final int percent;

  /// What the other intent offers that overlaps with what mine needs.
  final List<String> theyOfferYouNeed;

  /// What mine offers that overlaps with what the other intent needs.
  final List<String> youOfferTheyNeed;

  bool get hasAnyMatch => theyOfferYouNeed.isNotEmpty || youOfferTheyNeed.isNotEmpty;
}

/// Returns null when neither intent lists anything to compare (nothing
/// needed/offered on either side).
IntentMatchResult? computeReciprocalIntentMatch({required UserIntent mine, required UserIntent other}) {
  final wanted = {...mine.skillsNeeded, ...other.skillsNeeded};
  if (wanted.isEmpty && mine.skillsOffered.isEmpty && other.skillsOffered.isEmpty) return null;

  List<String> overlap(List<String> a, List<String> b) {
    final bLower = b.map((s) => s.toLowerCase()).toSet();
    return a.where((s) => bLower.contains(s.toLowerCase())).toList();
  }

  final theyOfferYouNeed = overlap(mine.skillsNeeded, other.skillsOffered);
  final youOfferTheyNeed = overlap(mine.skillsOffered, other.skillsNeeded);

  final totalAsked = mine.skillsNeeded.length + other.skillsNeeded.length;
  if (totalAsked == 0) return null;

  final matched = theyOfferYouNeed.length + youOfferTheyNeed.length;
  final percent = ((matched / totalAsked) * 100).clamp(0, 100).round();

  return IntentMatchResult(percent: percent, theyOfferYouNeed: theyOfferYouNeed, youOfferTheyNeed: youOfferTheyNeed);
}
