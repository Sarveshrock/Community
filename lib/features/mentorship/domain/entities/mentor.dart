/// A mentor's public profile (`mentor_profiles`, one row per user — the
/// `profile_id` primary key is what already prevents more than one mentor
/// profile per user). New fields (headline/mentorshipType/
/// communicationModes/availabilityNote) come from
/// 0045_mentor_profile_details.sql; every other field predates the "Become
/// a Mentor" flow and is reused as-is.
class Mentor {
  const Mentor({
    required this.profileId,
    this.available = true,
    this.expertise = const [],
    this.topics = const [],
    this.sessionDurationMinutes = 30,
    this.pricingType = 'free',
    this.price,
    this.currency,
    this.bio,
    this.headline,
    this.mentorshipType,
    this.communicationModes = const [],
    this.availabilityNote,
    this.fullName,
    this.avatarUrl,
    this.currentRole,
  });

  final String profileId;
  final bool available;
  final List<String> expertise;
  final List<String> topics;
  final int sessionDurationMinutes;
  final String pricingType;
  final num? price;
  final String? currency;
  final String? bio;
  final String? headline;
  final String? mentorshipType;
  final List<String> communicationModes;
  final String? availabilityNote;
  final String? fullName;
  final String? avatarUrl;
  final String? currentRole;

  bool get isFree => pricingType == 'free';
  bool get isAccepting => available;

  factory Mentor.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return Mentor(
      profileId: json['profile_id'] as String,
      available: json['available'] as bool? ?? true,
      expertise:
          (json['expertise'] as List<dynamic>?)?.cast<String>() ?? const [],
      topics: (json['topics'] as List<dynamic>?)?.cast<String>() ?? const [],
      sessionDurationMinutes:
          (json['session_duration_minutes'] as num?)?.toInt() ?? 30,
      pricingType: json['pricing_type'] as String? ?? 'free',
      price: json['price'] as num?,
      currency: json['currency'] as String?,
      bio: json['bio'] as String?,
      headline: json['headline'] as String?,
      mentorshipType: json['mentorship_type'] as String?,
      communicationModes:
          (json['communication_modes'] as List<dynamic>?)?.cast<String>() ?? const [],
      availabilityNote: json['availability_note'] as String?,
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      currentRole: profile?['current_role'] as String?,
    );
  }
}

/// "What can you help with?" — mirrors `kJobBenefits`'s pattern of a plain
/// Dart list over a `text[]` column (`topics`), not a new DB enum.
const kMentorshipTopics = <String>[
  'Career guidance',
  'Interview preparation',
  'Resume review',
  'Project guidance',
  'Code review',
  'System design',
  'Learning roadmap',
  'Technical guidance',
  'Career transition',
  'Portfolio review',
];

const kMentorshipTypes = <String>['1:1', 'Group', 'Both'];

class CommunicationMode {
  CommunicationMode._();

  static const chat = 'chat';
  static const videoCall = 'video_call';
  static const voiceCall = 'voice_call';
  static const inPerson = 'in_person';

  static const values = [chat, videoCall, voiceCall, inPerson];

  static String label(String mode) => switch (mode) {
        chat => 'Chat',
        videoCall => 'Video call',
        voiceCall => 'Voice call',
        inPerson => 'In-person',
        _ => mode,
      };
}
