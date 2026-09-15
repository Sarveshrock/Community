/// The reusable output shape of Communeo's matching engine (spec-extension:
/// AI/Smart Matching). Every match must be explainable — [reasons] is never
/// empty, and the skill/interest breakdowns let the UI answer "why am I
/// seeing this?" instead of showing a bare percentage. Designed generic on
/// purpose: later consumers (hackathon team recommendations, "People You
/// Should Meet") are expected to reuse this same shape, not invent their own.
class MatchResult {
  const MatchResult({
    required this.candidateId,
    required this.score,
    this.reasons = const [],
    this.matchedSkills = const [],
    this.missingSkills = const [],
    this.complementarySkills = const [],
    this.sharedInterests = const [],
    this.availabilityCompatible,
    this.fullName,
    this.avatarUrl,
    this.currentRole,
    this.currentCompany,
    this.aiRationale,
    this.scoreBreakdown = const {},
  });

  final String candidateId;
  final num score;
  final List<String> reasons;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final List<String> complementarySkills;
  final List<String> sharedInterests;

  /// null = not enough availability data from one or both sides to tell.
  final bool? availabilityCompatible;

  final String? fullName;
  final String? avatarUrl;
  final String? currentRole;
  final String? currentCompany;

  /// A real, LLM-generated one-sentence explanation of this match — null
  /// when no AI provider is configured (see aiProvider.ts's NoopProvider) or
  /// the candidate fell outside the top few sent for rationale generation.
  /// [reasons] is always present regardless; this is a richer restatement
  /// of the same underlying signals, never a replacement.
  final String? aiRationale;

  /// The individual weighted components (skills/interests/experience/
  /// availability, each 0-1) behind [score] — keys match `score_breakdown`
  /// from `ai-match-intent`. Empty for matches computed before this field
  /// existed; callers should treat a missing key as "unknown", not zero.
  final Map<String, num> scoreBreakdown;

  String get displayName => fullName?.isNotEmpty == true ? fullName! : 'Community member';

  bool get hasAiRationale => aiRationale != null && aiRationale!.trim().isNotEmpty;

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return MatchResult(
      candidateId: json['candidate_id'] as String,
      score: json['score'] as num,
      reasons: (json['reasons'] as List<dynamic>?)?.cast<String>() ?? const [],
      matchedSkills: (json['matched_skills'] as List<dynamic>?)?.cast<String>() ?? const [],
      missingSkills: (json['missing_skills'] as List<dynamic>?)?.cast<String>() ?? const [],
      complementarySkills: (json['complementary_skills'] as List<dynamic>?)?.cast<String>() ?? const [],
      sharedInterests: (json['shared_interests'] as List<dynamic>?)?.cast<String>() ?? const [],
      availabilityCompatible: json['availability_compatible'] as bool?,
      fullName: profile?['full_name'] as String? ?? json['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String? ?? json['avatar_url'] as String?,
      currentRole: profile?['current_role'] as String? ?? json['current_role'] as String?,
      currentCompany: profile?['current_company'] as String? ?? json['current_company'] as String?,
      aiRationale: json['ai_rationale'] as String?,
      scoreBreakdown: (json['score_breakdown'] as Map<String, dynamic>?)?.cast<String, num>() ?? const {},
    );
  }
}
