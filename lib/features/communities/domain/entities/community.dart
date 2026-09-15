/// A community — the parent entity for members, discussions, pre-join Q&A,
/// group chat, and (via `events.community_id`, already existing) events.
/// New fields (tagline/logoUrl/activities/audience/rules/topics/accessType)
/// come from 0047_community_rich_details.sql; every other field predates
/// this redesign and is reused as-is.
class Community {
  const Community({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    this.description,
    this.coverImageUrl,
    this.communityType = 'interest_based',
    this.isPrivate = false,
    this.memberCount = 0,
    this.tagline,
    this.logoUrl,
    this.activities = const [],
    this.audience = const [],
    this.rules,
    this.accessType = 'public',
    this.topicNames = const [],
  });

  final String id;
  final String ownerId;
  final String name;
  final String slug;
  final String? description;
  final String? coverImageUrl;
  final String communityType;
  final bool isPrivate;
  final int memberCount;
  final String? tagline;
  final String? logoUrl;
  final List<String> activities;
  final List<String> audience;
  final String? rules;
  final String accessType;
  final List<String> topicNames;

  bool get isPublic => accessType == 'public';
  bool get isRequestToJoin => accessType == 'request_to_join';
  bool isOwner(String? profileId) => profileId != null && profileId == ownerId;

  factory Community.fromJson(Map<String, dynamic> json) => Community(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        coverImageUrl: json['cover_image_url'] as String?,
        communityType: json['community_type'] as String? ?? 'interest_based',
        isPrivate: json['is_private'] as bool? ?? false,
        memberCount: (json['community_members'] is List)
            ? (json['community_members'] as List).length
            : 0,
        tagline: json['tagline'] as String?,
        logoUrl: json['logo_url'] as String?,
        activities: (json['activities'] as List<dynamic>?)?.cast<String>() ?? const [],
        audience: (json['audience'] as List<dynamic>?)?.cast<String>() ?? const [],
        rules: json['rules'] as String?,
        accessType: json['access_type'] as String? ?? 'public',
        topicNames: (json['community_topics'] as List<dynamic>?)
                ?.map((e) => (e as Map<String, dynamic>)['skills'] as Map<String, dynamic>?)
                .map((s) => s?['name'] as String?)
                .whereType<String>()
                .toList() ??
            const [],
      );
}

/// One row of `community_members`, with the joined profile info needed for
/// the Members section.
class CommunityMember {
  const CommunityMember({
    required this.profileId,
    required this.role,
    this.fullName,
    this.avatarUrl,
    this.headline,
    this.joinedAt,
  });

  final String profileId;
  final String role;
  final String? fullName;
  final String? avatarUrl;
  final String? headline;
  final DateTime? joinedAt;

  bool get isOwnerRole => role == 'admin';
  bool get isModerator => role == 'moderator';
  String get displayName => (fullName?.isNotEmpty ?? false) ? fullName! : 'Community member';

  factory CommunityMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final role = profile?['current_role'] as String?;
    final company = profile?['current_company'] as String?;
    final headline = (role != null && company != null) ? '$role at $company' : role;
    final joinedAtRaw = json['joined_at'] as String?;
    return CommunityMember(
      profileId: json['profile_id'] as String,
      role: json['role'] as String? ?? 'member',
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      headline: headline,
      joinedAt: joinedAtRaw != null ? DateTime.parse(joinedAtRaw) : null,
    );
  }
}

class CommunityJoinRequest {
  const CommunityJoinRequest({
    required this.id,
    required this.communityId,
    required this.requesterId,
    required this.status,
    required this.createdAt,
    this.message,
    this.requesterName,
    this.requesterAvatarUrl,
  });

  final String id;
  final String communityId;
  final String requesterId;
  final String status;
  final DateTime createdAt;
  final String? message;
  final String? requesterName;
  final String? requesterAvatarUrl;

  factory CommunityJoinRequest.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return CommunityJoinRequest(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      requesterId: json['requester_id'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      message: json['message'] as String?,
      requesterName: profile?['full_name'] as String?,
      requesterAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}

/// A pre-join question, with its answers (spec: distinct from member
/// discussions — never mixed into the same feed).
class CommunityQuestion {
  const CommunityQuestion({
    required this.id,
    required this.communityId,
    required this.askerId,
    required this.questionText,
    required this.createdAt,
    this.askerName,
    this.askerAvatarUrl,
    this.answers = const [],
  });

  final String id;
  final String communityId;
  final String askerId;
  final String questionText;
  final DateTime createdAt;
  final String? askerName;
  final String? askerAvatarUrl;
  final List<CommunityAnswer> answers;

  factory CommunityQuestion.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return CommunityQuestion(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      askerId: json['asker_id'] as String,
      questionText: json['question_text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      askerName: profile?['full_name'] as String?,
      askerAvatarUrl: profile?['avatar_url'] as String?,
      answers: (json['community_answers'] as List<dynamic>?)
              ?.map((e) => CommunityAnswer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class CommunityAnswer {
  const CommunityAnswer({
    required this.id,
    required this.questionId,
    required this.responderId,
    required this.answerText,
    required this.createdAt,
    this.responderName,
    this.responderAvatarUrl,
  });

  final String id;
  final String questionId;
  final String responderId;
  final String answerText;
  final DateTime createdAt;
  final String? responderName;
  final String? responderAvatarUrl;

  factory CommunityAnswer.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return CommunityAnswer(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      responderId: json['responder_id'] as String,
      answerText: json['answer_text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      responderName: profile?['full_name'] as String?,
      responderAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.authorName,
    this.authorAvatar,
    this.isAnnouncement = false,
    this.commentCount = 0,
  });

  final String id;
  final String communityId;
  final String authorId;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatar;
  final bool isAnnouncement;
  final int commentCount;

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final author = json['profiles'] as Map<String, dynamic>?;
    final comments = json['community_comments'];
    return CommunityPost(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: author?['full_name'] as String?,
      authorAvatar: author?['avatar_url'] as String?,
      isAnnouncement: json['is_announcement'] as bool? ?? false,
      commentCount: comments is List ? comments.length : 0,
    );
  }
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.authorName,
    this.authorAvatar,
  });

  final String id;
  final String postId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatar;

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    final author = json['profiles'] as Map<String, dynamic>?;
    return CommunityComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: author?['full_name'] as String?,
      authorAvatar: author?['avatar_url'] as String?,
    );
  }
}

// ============================================================================
// Structured option lists — plain Dart lists (mirrors kJobCategories'
// pattern), backed by the DB enum for communityType/accessType and plain
// text[] columns for activities/audience — not new taxonomy tables.
// ============================================================================

/// Shown in the Create Community dropdown — matches this task's suggested
/// type list. `city`/`student`/`research`/`open_source` are older enum
/// values (0002_enums.sql) some existing communities may still carry; they
/// aren't offered for new communities but [communityTypeLabel] still
/// labels them correctly so old communities never show a blank/wrong type.
const kCommunityTypes = <String>[
  'interest_based',
  'professional',
  'technology',
  'career',
  'college',
  'local',
  'project',
  'startup',
  'learning',
  'other',
];

String communityTypeLabel(String type) => switch (type) {
      'interest_based' => 'Interest Based',
      'professional' => 'Professional',
      'technology' => 'Technology',
      'career' => 'Career',
      'college' => 'College / University',
      'local' => 'Local',
      'project' => 'Project',
      'startup' => 'Startup',
      'learning' => 'Learning',
      'city' => 'Local',
      'student' => 'College / University',
      'research' => 'Learning',
      'open_source' => 'Project',
      _ => 'Other',
    };

const kCommunityActivities = <String>[
  'Discussions',
  'Learning',
  'Networking',
  'Career opportunities',
  'Projects',
  'Hackathons',
  'Events',
  'Q&A',
  'Resource sharing',
  'Other',
];

String communityActivityEmoji(String activity) => switch (activity) {
      'Discussions' => '💬',
      'Learning' => '📚',
      'Networking' => '🤝',
      'Career opportunities' => '💼',
      'Projects' => '🚀',
      'Hackathons' => '🏆',
      'Events' => '🎤',
      'Q&A' => '❓',
      'Resource sharing' => '📎',
      _ => '✨',
    };

const kCommunityAudiences = <String>[
  'Students',
  'Beginners',
  'Developers',
  'Designers',
  'Founders',
  'Professionals',
  'Researchers',
  'Job seekers',
  'Anyone',
];

const kCommunityAccessTypes = <String>['public', 'request_to_join', 'private'];

String communityAccessTypeLabel(String accessType) => switch (accessType) {
      'request_to_join' => 'Request to join',
      'private' => 'Private',
      _ => 'Public',
    };
