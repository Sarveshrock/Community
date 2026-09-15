import '../../../../core/models/skill.dart';

enum IntentType {
  findHackathonTeam,
  findHackathonTeammates,
  findJob,
  findInternship,
  findCofounder,
  findDeveloper,
  findDesigner,
  findMentor,
  findCollaborator,
  findProject,
  findStartupOpportunity,
  findReferral,
  findMockInterviewPartner,
  findStudyPartner,
  findOpenSourceContributor,
  findResearchCollaborator,
  offerMentorship,
  offerReferral,
  offerCollaboration,
  networking,
}

extension IntentTypeX on IntentType {
  String get value => switch (this) {
        IntentType.findHackathonTeam => 'find_hackathon_team',
        IntentType.findHackathonTeammates => 'find_hackathon_teammates',
        IntentType.findJob => 'find_job',
        IntentType.findInternship => 'find_internship',
        IntentType.findCofounder => 'find_cofounder',
        IntentType.findDeveloper => 'find_developer',
        IntentType.findDesigner => 'find_designer',
        IntentType.findMentor => 'find_mentor',
        IntentType.findCollaborator => 'find_collaborator',
        IntentType.findProject => 'find_project',
        IntentType.findStartupOpportunity => 'find_startup_opportunity',
        IntentType.findReferral => 'find_referral',
        IntentType.findMockInterviewPartner => 'find_mock_interview_partner',
        IntentType.findStudyPartner => 'find_study_partner',
        IntentType.findOpenSourceContributor => 'find_open_source_contributor',
        IntentType.findResearchCollaborator => 'find_research_collaborator',
        IntentType.offerMentorship => 'offer_mentorship',
        IntentType.offerReferral => 'offer_referral',
        IntentType.offerCollaboration => 'offer_collaboration',
        IntentType.networking => 'networking',
      };

  String get label => switch (this) {
        IntentType.findHackathonTeam => 'Find Hackathon Team',
        IntentType.findHackathonTeammates => 'Find Hackathon Teammates',
        IntentType.findJob => 'Find a Job',
        IntentType.findInternship => 'Find Internship',
        IntentType.findCofounder => 'Find Co-founder',
        IntentType.findDeveloper => 'Find Developer',
        IntentType.findDesigner => 'Find Designer',
        IntentType.findMentor => 'Find a Mentor',
        IntentType.findCollaborator => 'Find Collaborator',
        IntentType.findProject => 'Find Project',
        IntentType.findStartupOpportunity => 'Find Startup Opportunity',
        IntentType.findReferral => 'Find Referral',
        IntentType.findMockInterviewPartner => 'Find Mock Interview Partner',
        IntentType.findStudyPartner => 'Learn / Study Together',
        IntentType.findOpenSourceContributor => 'Find Open Source Contributor',
        IntentType.findResearchCollaborator => 'Find Research Collaborator',
        IntentType.offerMentorship => 'Offer Mentorship',
        IntentType.offerReferral => 'Offer Referral',
        IntentType.offerCollaboration => 'Offer Collaboration',
        IntentType.networking => 'Networking',
      };

  /// One-line blurb shown under the label in the Create Intent screen's
  /// intent-type picker — purely a UI label, not persisted.
  String get shortDescription => switch (this) {
        IntentType.findHackathonTeam => 'Build for a hackathon',
        IntentType.findHackathonTeammates => 'Fill out your hackathon team',
        IntentType.findJob => 'Discover career opportunities',
        IntentType.findInternship => 'Find an internship opportunity',
        IntentType.findCofounder => 'Start something big together',
        IntentType.findDeveloper => 'Find a developer to work with',
        IntentType.findDesigner => 'Find a designer to work with',
        IntentType.findMentor => 'Get guidance and advice',
        IntentType.findCollaborator => 'Work on a project together',
        IntentType.findProject => 'Contribute to projects',
        IntentType.findStartupOpportunity => 'Find a role at a startup',
        IntentType.findReferral => 'Ask for a referral',
        IntentType.findMockInterviewPartner => 'Practice interviews together',
        IntentType.findStudyPartner => 'Learn with peers',
        IntentType.findOpenSourceContributor => 'Find contributors for your project',
        IntentType.findResearchCollaborator => 'Collaborate on research',
        IntentType.offerMentorship => 'Share your expertise',
        IntentType.offerReferral => 'Offer to refer others',
        IntentType.offerCollaboration => 'Offer to collaborate on a project',
        IntentType.networking => 'Expand your network',
      };

  static IntentType fromValue(String? value) {
    return IntentType.values.firstWhere((e) => e.value == value,
        orElse: () => IntentType.findCollaborator);
  }
}

enum IntentVisibility { public, connectionsOnly }

extension IntentVisibilityX on IntentVisibility {
  String get value =>
      this == IntentVisibility.connectionsOnly ? 'connections_only' : 'public';

  String get label =>
      this == IntentVisibility.connectionsOnly ? 'Connections only' : 'Public';

  static IntentVisibility fromValue(String? value) {
    return value == 'connections_only'
        ? IntentVisibility.connectionsOnly
        : IntentVisibility.public;
  }
}

enum IntentStatus { active, paused, cancelled, fulfilled }

extension IntentStatusX on IntentStatus {
  String get value => name;

  String get label => switch (this) {
        IntentStatus.active => 'Active',
        IntentStatus.paused => 'Paused',
        IntentStatus.cancelled => 'Cancelled',
        IntentStatus.fulfilled => 'Fulfilled',
      };

  static IntentStatus fromValue(String? value) {
    return IntentStatus.values.firstWhere((e) => e.value == value,
        orElse: () => IntentStatus.active);
  }
}

/// A user's declared "what I want to accomplish right now" (spec-extension:
/// Intent System) — the thing the matching engine (see
/// `features/matching/domain/entities/match_result.dart`) matches candidates
/// against. Expiry is derived, not stored: an intent is only ever
/// active/paused/cancelled in the database, and [isExpired] compares
/// [expiresAt] against the clock at read time — mirrors the RLS policy in
/// `0036_intents.sql`, which hides other people's expired intents the same
/// way without needing a cron job to flip a status column.
class UserIntent {
  const UserIntent({
    required this.id,
    required this.profileId,
    required this.intentType,
    required this.title,
    this.description,
    this.experienceLevel = ExperienceLevel.intermediate,
    this.preferredRole,
    this.locationPreference,
    this.workMode,
    this.commitmentLevel,
    this.relatedHackathonId,
    this.relatedProjectId,
    this.relatedJobId,
    this.relatedStartupId,
    this.visibility = IntentVisibility.public,
    this.status = IntentStatus.active,
    required this.expiresAt,
    required this.createdAt,
    this.skillsNeeded = const [],
    this.skillsOffered = const [],
    this.metadata = const {},
    this.fullName,
    this.avatarUrl,
    this.currentRole,
  });

  final String id;
  final String profileId;
  final IntentType intentType;
  final String title;
  final String? description;
  final ExperienceLevel experienceLevel;
  final String? preferredRole;
  final String? locationPreference;
  final String? workMode;
  final String? commitmentLevel;
  final String? relatedHackathonId;
  final String? relatedProjectId;
  final String? relatedJobId;
  final String? relatedStartupId;
  final IntentVisibility visibility;
  final IntentStatus status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final List<String> skillsNeeded;
  final List<String> skillsOffered;

  /// Intent-type-specific structured data (0048_intent_structured_details.sql)
  /// — shape is driven entirely by [intentTypeConfig] (see
  /// `domain/intent_config.dart`), never hardcoded here. Empty for every
  /// intent posted before this migration.
  final Map<String, dynamic> metadata;

  final String? fullName;
  final String? avatarUrl;
  final String? currentRole;

  bool get isExpired => expiresAt.isBefore(DateTime.now());
  bool get isFulfilled => status == IntentStatus.fulfilled;

  /// What actually governs visibility/matching right now — active status
  /// AND not yet past its expiry.
  bool get isEffectivelyActive => status == IntentStatus.active && !isExpired;

  /// Days remaining until [expiresAt], clamped to 0 once past. Purely a
  /// display helper — expiry itself is still derived from [expiresAt], per
  /// the RLS policy in 0036_intents.sql.
  int get daysUntilExpiry => expiresAt.difference(DateTime.now()).inDays.clamp(0, 1 << 30);

  /// 🟢 Active / 🟡 Expiring Soon / 🔴 Expired / ✅ Fulfilled — spec's exact
  /// status vocabulary, derived rather than a 5th stored value.
  String get statusLabel {
    if (isFulfilled) return 'Fulfilled';
    if (status == IntentStatus.cancelled) return 'Cancelled';
    if (isExpired) return 'Expired';
    if (status == IntentStatus.paused) return 'Paused';
    if (daysUntilExpiry <= 3) return 'Expiring Soon';
    return 'Active';
  }

  factory UserIntent.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final skillRows = (json['intent_skills'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    return UserIntent(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      intentType: IntentTypeX.fromValue(json['intent_type'] as String?),
      title: json['title'] as String,
      description: json['description'] as String?,
      experienceLevel:
          ExperienceLevelX.fromValue(json['experience_level'] as String?),
      preferredRole: json['preferred_role'] as String?,
      locationPreference: json['location_preference'] as String?,
      workMode: json['work_mode'] as String?,
      commitmentLevel: json['commitment_level'] as String?,
      relatedHackathonId: json['related_hackathon_id'] as String?,
      relatedProjectId: json['related_project_id'] as String?,
      relatedJobId: json['related_job_id'] as String?,
      relatedStartupId: json['related_startup_id'] as String?,
      visibility: IntentVisibilityX.fromValue(json['visibility'] as String?),
      status: IntentStatusX.fromValue(json['status'] as String?),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      skillsNeeded: skillRows
          .where((r) => r['direction'] == 'needed')
          .map((r) => (r['skills'] as Map<String, dynamic>?)?['name'] as String?)
          .whereType<String>()
          .toList(),
      skillsOffered: skillRows
          .where((r) => r['direction'] == 'offered')
          .map((r) => (r['skills'] as Map<String, dynamic>?)?['name'] as String?)
          .whereType<String>()
          .toList(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      currentRole: profile?['current_role'] as String?,
    );
  }
}
