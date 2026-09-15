import '../../../../core/models/skill.dart';

enum InterviewPracticeStatus { pending, accepted, declined, cancelled, completed }

extension InterviewPracticeStatusX on InterviewPracticeStatus {
  String get value => name;

  String get label => switch (this) {
        InterviewPracticeStatus.pending => 'Requested',
        InterviewPracticeStatus.accepted => 'Accepted',
        InterviewPracticeStatus.declined => 'Declined',
        InterviewPracticeStatus.cancelled => 'Cancelled',
        InterviewPracticeStatus.completed => 'Completed',
      };

  static InterviewPracticeStatus fromValue(String? value) {
    return InterviewPracticeStatus.values.firstWhere((e) => e.value == value,
        orElse: () => InterviewPracticeStatus.pending);
  }
}

/// A member's standing listing in the mock-interview practice pool
/// (spec-extension: Mock Interview Matching).
class InterviewPracticeProfile {
  const InterviewPracticeProfile({
    required this.profileId,
    required this.targetRole,
    this.topics = const [],
    this.experienceLevel = ExperienceLevel.intermediate,
    this.availabilityNotes,
    this.isActive = true,
    this.fullName,
    this.avatarUrl,
    this.currentRole,
  });

  final String profileId;
  final String targetRole;
  final List<String> topics;
  final ExperienceLevel experienceLevel;
  final String? availabilityNotes;
  final bool isActive;
  final String? fullName;
  final String? avatarUrl;
  final String? currentRole;

  factory InterviewPracticeProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return InterviewPracticeProfile(
      profileId: json['profile_id'] as String,
      targetRole: json['target_role'] as String,
      topics: (json['topics'] as List<dynamic>?)?.cast<String>() ?? const [],
      experienceLevel:
          ExperienceLevelX.fromValue(json['experience_level'] as String?),
      availabilityNotes: json['availability_notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      currentRole: profile?['current_role'] as String?,
    );
  }
}

/// One pairing request between two members of the practice pool.
class InterviewPracticeRequest {
  const InterviewPracticeRequest({
    required this.id,
    required this.requesterId,
    required this.partnerId,
    required this.targetRole,
    this.message,
    this.status = InterviewPracticeStatus.pending,
    required this.createdAt,
    this.requesterName,
    this.requesterAvatarUrl,
    this.partnerName,
    this.partnerAvatarUrl,
  });

  final String id;
  final String requesterId;
  final String partnerId;
  final String targetRole;
  final String? message;
  final InterviewPracticeStatus status;
  final DateTime createdAt;
  final String? requesterName;
  final String? requesterAvatarUrl;
  final String? partnerName;
  final String? partnerAvatarUrl;

  factory InterviewPracticeRequest.fromJson(Map<String, dynamic> json) {
    final requester = json['requester'] as Map<String, dynamic>?;
    final partner = json['partner'] as Map<String, dynamic>?;
    return InterviewPracticeRequest(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      partnerId: json['partner_id'] as String,
      targetRole: json['target_role'] as String,
      message: json['message'] as String?,
      status: InterviewPracticeStatusX.fromValue(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      requesterName: requester?['full_name'] as String?,
      requesterAvatarUrl: requester?['avatar_url'] as String?,
      partnerName: partner?['full_name'] as String?,
      partnerAvatarUrl: partner?['avatar_url'] as String?,
    );
  }
}
