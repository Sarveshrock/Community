/// A lightweight named reference to an external hackathon (spec: no hosting
/// inside the app — no dates/prizes/rules/registration). People post team
/// requirements against it; the real event happens on the organizer's own
/// site.
class Hackathon {
  const Hackathon({
    required this.id,
    required this.name,
    this.eventDate,
    this.createdBy,
    this.teamRequirementCount = 0,
  });

  final String id;
  final String name;
  final DateTime? eventDate;
  final String? createdBy;
  final int teamRequirementCount;

  factory Hackathon.fromJson(Map<String, dynamic> json) => Hackathon(
        id: json['id'] as String,
        name: json['name'] as String,
        eventDate: json['event_date'] != null
            ? DateTime.parse(json['event_date'] as String)
            : null,
        createdBy: json['created_by'] as String?,
        teamRequirementCount: (json['hackathon_team_requirements'] is List)
            ? (json['hackathon_team_requirements'] as List).length
            : 0,
      );
}

/// One row of `hackathon_team_members`, with the joined profile info needed
/// for the "Team Members" section (spec section 2) — name, avatar, and
/// whatever headline the profile already exposes elsewhere in the app.
/// [fullName]/[avatarUrl]/[headline] come back null when the member's
/// profile row is filtered out by `profiles_select_discoverable` RLS (the
/// existing privacy rule) rather than actually being empty — the UI falls
/// back to a generic label instead of guessing.
class TeamMemberInfo {
  const TeamMemberInfo({
    required this.profileId,
    this.fullName,
    this.avatarUrl,
    this.headline,
    this.joinedAt,
  });

  final String profileId;
  final String? fullName;
  final String? avatarUrl;
  final String? headline;
  final DateTime? joinedAt;

  String get displayName =>
      (fullName?.isNotEmpty ?? false) ? fullName! : 'Team member';

  factory TeamMemberInfo.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final role = profile?['current_role'] as String?;
    final company = profile?['current_company'] as String?;
    final headline =
        (role != null && company != null) ? '$role at $company' : role;
    final joinedAtRaw = json['joined_at'] as String?;
    return TeamMemberInfo(
      profileId: json['profile_id'] as String,
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      headline: headline,
      joinedAt: joinedAtRaw != null ? DateTime.parse(joinedAtRaw) : null,
    );
  }
}

/// One structured "Looking For" role (0046_hackathon_team_details.sql) —
/// replaces the flat `required_roles text[]` for new teams; old teams
/// simply have an empty [TeamRequirement.roleRequirements] and keep
/// rendering via [TeamRequirement.requiredRoles] instead.
class TeamRoleRequirement {
  const TeamRoleRequirement({
    required this.id,
    required this.teamRequirementId,
    required this.roleName,
    this.priority,
    this.description,
    this.experienceLevel,
    this.sortOrder = 0,
    this.skillNames = const [],
  });

  final String id;
  final String teamRequirementId;
  final String roleName;
  final String? priority;
  final String? description;
  final String? experienceLevel;
  final int sortOrder;
  final List<String> skillNames;

  factory TeamRoleRequirement.fromJson(Map<String, dynamic> json) => TeamRoleRequirement(
        id: json['id'] as String,
        teamRequirementId: json['team_requirement_id'] as String,
        roleName: json['role_name'] as String,
        priority: json['priority'] as String?,
        description: json['description'] as String?,
        experienceLevel: json['experience_level'] as String?,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        skillNames: (json['hackathon_team_role_required_skills'] as List<dynamic>?)
                ?.map((e) => (e as Map<String, dynamic>)['skills'] as Map<String, dynamic>?)
                .map((s) => s?['name'] as String?)
                .whereType<String>()
                .toList() ??
            const [],
      );

  Map<String, dynamic> toInsertJson(String teamRequirementId) => {
        'team_requirement_id': teamRequirementId,
        'role_name': roleName,
        'priority': priority,
        'description': description,
        'experience_level': experienceLevel,
        'sort_order': sortOrder,
      };
}

class TeamRequirement {
  const TeamRequirement({
    required this.id,
    required this.hackathonId,
    required this.creatorId,
    required this.teamName,
    this.description,
    this.requiredRoles = const [],
    this.requiredSkillNames = const [],
    this.teamSize = 4,
    this.status = 'open',
    this.creatorName,
    this.creatorAvatarUrl,
    this.memberIds = const [],
    this.members = const [],
    this.tagline,
    this.projectStage,
    this.minTeamSize,
    this.commitment,
    this.preferredTimes,
    this.timezone,
    this.collaborationMode = 'online',
    this.location,
    this.communicationPlatform,
    this.preferredExperienceLevel,
    this.teamCulture = const [],
    this.expectations,
    this.githubUrl,
    this.figmaUrl,
    this.websiteUrl,
    this.demoUrl,
    this.pitchDeckUrl,
    this.visibility = 'public',
    this.roleRequirements = const [],
    this.skillsHaveNames = const [],
  });

  final String id;
  final String hackathonId;
  final String creatorId;
  final String teamName;
  final String? description;
  final List<String> requiredRoles;
  final List<String> requiredSkillNames;
  final int teamSize;
  final String status;
  final String? creatorName;
  final String? creatorAvatarUrl;

  /// Everyone currently on the team, including the creator — a team
  /// requirement's creator has always implicitly counted as its first
  /// member (see migration 0026's backfill).
  final List<String> memberIds;

  /// Same membership, with profile info attached for the members list UI.
  final List<TeamMemberInfo> members;

  final String? tagline;
  final String? projectStage;
  final int? minTeamSize;
  final String? commitment;
  final String? preferredTimes;
  final String? timezone;
  final String collaborationMode;
  final String? location;
  final String? communicationPlatform;
  final String? preferredExperienceLevel;
  final List<String> teamCulture;
  final String? expectations;
  final String? githubUrl;
  final String? figmaUrl;
  final String? websiteUrl;
  final String? demoUrl;
  final String? pitchDeckUrl;
  final String visibility;

  /// Structured "Looking For" roles (0046) — empty for teams posted before
  /// this migration, which fall back to [requiredRoles] instead.
  final List<TeamRoleRequirement> roleRequirements;

  /// "Skills we already have" (0046) — distinct from [requiredSkillNames],
  /// which is "skills we're looking for".
  final List<String> skillsHaveNames;

  int get memberCount => memberIds.length;
  int get openSlots => (teamSize - memberCount).clamp(0, teamSize);
  bool isMember(String? profileId) =>
      profileId != null && memberIds.contains(profileId);
  bool isOwner(String? profileId) =>
      profileId != null && profileId == creatorId;
  bool get isFull => status == 'full' || memberCount >= teamSize;
  bool get isOpen => status == 'open' && !isFull;
  bool get isClosed => status == 'closed';
  bool get hasProjectLinks =>
      githubUrl != null || figmaUrl != null || websiteUrl != null || demoUrl != null || pitchDeckUrl != null;
  bool get isInPerson => collaborationMode == 'in_person';
  bool get isHybrid => collaborationMode == 'hybrid';
  bool get isOnline => collaborationMode == 'online';

  /// A human status derived from membership/settings rather than trusted
  /// blindly from the raw `status` column (spec section 7) — "Almost full"
  /// only ever shown for an actually-open team with exactly one slot left.
  String get statusLabel {
    if (isClosed) return 'Not accepting members';
    if (isFull) return 'Full';
    if (openSlots == 1) return 'Almost full';
    return 'Looking for members';
  }

  factory TeamRequirement.fromJson(Map<String, dynamic> json) {
    final memberRows = (json['hackathon_team_members'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    return TeamRequirement(
      id: json['id'] as String,
      hackathonId: json['hackathon_id'] as String,
      creatorId: json['creator_id'] as String,
      teamName: json['team_name'] as String,
      description: json['description'] as String?,
      requiredRoles:
          (json['required_roles'] as List<dynamic>?)?.cast<String>() ??
              const [],
      requiredSkillNames:
          (json['hackathon_team_required_skills'] as List<dynamic>?)
                  ?.map((e) => (e as Map<String, dynamic>)['skills']
                      as Map<String, dynamic>?)
                  .map((s) => s?['name'] as String?)
                  .whereType<String>()
                  .toList() ??
              const [],
      teamSize: (json['team_size'] as num?)?.toInt() ?? 4,
      status: json['status'] as String? ?? 'open',
      creatorName:
          (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
      creatorAvatarUrl:
          (json['profiles'] as Map<String, dynamic>?)?['avatar_url'] as String?,
      memberIds: memberRows.map((e) => e['profile_id'] as String).toList(),
      members: memberRows.map(TeamMemberInfo.fromJson).toList(),
      tagline: json['tagline'] as String?,
      projectStage: json['project_stage'] as String?,
      minTeamSize: (json['min_team_size'] as num?)?.toInt(),
      commitment: json['commitment'] as String?,
      preferredTimes: json['preferred_times'] as String?,
      timezone: json['timezone'] as String?,
      collaborationMode: json['collaboration_mode'] as String? ?? 'online',
      location: json['location'] as String?,
      communicationPlatform: json['communication_platform'] as String?,
      preferredExperienceLevel: json['preferred_experience_level'] as String?,
      teamCulture: (json['team_culture'] as List<dynamic>?)?.cast<String>() ?? const [],
      expectations: json['expectations'] as String?,
      githubUrl: json['github_url'] as String?,
      figmaUrl: json['figma_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      demoUrl: json['demo_url'] as String?,
      pitchDeckUrl: json['pitch_deck_url'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      roleRequirements: (() {
        final roles = (json['hackathon_team_role_requirements'] as List<dynamic>?)
                ?.map((e) => TeamRoleRequirement.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <TeamRoleRequirement>[];
        roles.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return roles;
      })(),
      skillsHaveNames: (json['hackathon_team_skills_have'] as List<dynamic>?)
              ?.map((e) => (e as Map<String, dynamic>)['skills'] as Map<String, dynamic>?)
              .map((s) => s?['name'] as String?)
              .whereType<String>()
              .toList() ??
          const [],
    );
  }
}

/// A user's request to join a team they don't own (spec section 3) — the
/// direction team_invitations never covered.
class TeamJoinRequest {
  const TeamJoinRequest({
    required this.id,
    required this.teamRequirementId,
    required this.requesterId,
    required this.status,
    required this.createdAt,
    this.message,
    this.teamName,
    this.requesterName,
  });

  final String id;
  final String teamRequirementId;
  final String requesterId;
  final String status;
  final DateTime createdAt;
  final String? message;
  final String? teamName;
  final String? requesterName;

  factory TeamJoinRequest.fromJson(Map<String, dynamic> json) =>
      TeamJoinRequest(
        id: json['id'] as String,
        teamRequirementId: json['team_requirement_id'] as String,
        requesterId: json['requester_id'] as String,
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(json['created_at'] as String),
        message: json['message'] as String?,
        teamName: (json['hackathon_team_requirements']
            as Map<String, dynamic>?)?['team_name'] as String?,
        requesterName: (json['profiles'] as Map<String, dynamic>?)?['full_name']
            as String?,
      );
}

// ============================================================================
// Structured option lists — plain Dart lists over free-text columns
// (mirrors kJobCategories/kJobBenefits' pattern), not new DB enums, so the
// lists can grow without a migration.
// ============================================================================

const kTeamRoleOptions = <String>[
  'Frontend Developer',
  'Backend Developer',
  'Full Stack Developer',
  'AI/ML Engineer',
  'Data Scientist',
  'UI/UX Designer',
  'Product Manager',
  'DevOps Engineer',
  'Cybersecurity',
  'Blockchain Developer',
  'Pitch/Presentation',
  'Business/Marketing',
  'Other',
];

const kRolePriorities = <String>['High', 'Medium', 'Low'];

const kProjectStages = <String>['Idea', 'Planning', 'Prototype', 'Already Building', 'MVP', 'Other'];

const kCommitmentOptions = <String>['Weekend only', 'Few hours per week', 'Full hackathon', 'Flexible'];

const kCollaborationModes = <String>['online', 'in_person', 'hybrid'];

String collaborationModeLabel(String mode) => switch (mode) {
      'in_person' => 'In-person',
      'hybrid' => 'Hybrid',
      _ => 'Online',
    };

const kCommunicationPlatforms = <String>['Communeo Chat', 'Discord', 'Slack', 'Other'];

const kExperienceLevelOptions = <String>['Any', 'Beginner', 'Intermediate', 'Advanced'];

const kTeamCultureOptions = <String>[
  'Beginner friendly',
  'Experienced contributors',
  'Competitive',
  'Learning focused',
  'Creative',
  'Strong technical focus',
  'Product focused',
  'Open to everyone',
];

const kTeamVisibilityOptions = <String>['public', 'communeo_users', 'connections_only'];

String teamVisibilityLabel(String visibility) => switch (visibility) {
      'communeo_users' => 'Communeo users',
      'connections_only' => 'Connections only',
      _ => 'Public',
    };
