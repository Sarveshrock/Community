/// A speaker/host/mentor/judge/co-organizer for an event
/// (`event_speakers`) — linked to a real Communeo profile where one
/// exists, so this never duplicates a person record; free-text
/// name/role/company/bio cover external speakers who aren't on Communeo.
class EventSpeaker {
  const EventSpeaker({
    required this.id,
    required this.eventId,
    this.profileId,
    this.profileName,
    this.profileAvatarUrl,
    this.name,
    this.role,
    this.company,
    this.bio,
    this.sortOrder = 0,
  });

  final String id;
  final String eventId;
  final String? profileId;
  final String? profileName;
  final String? profileAvatarUrl;
  final String? name;
  final String? role;
  final String? company;
  final String? bio;
  final int sortOrder;

  String get displayName => profileName ?? name ?? 'Speaker';

  factory EventSpeaker.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    return EventSpeaker(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      profileId: json['profile_id'] as String?,
      profileName: profile?['full_name'] as String?,
      profileAvatarUrl: profile?['avatar_url'] as String?,
      name: json['name'] as String?,
      role: json['role'] as String?,
      company: json['company'] as String?,
      bio: json['bio'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson(String eventId) => {
        'event_id': eventId,
        'profile_id': profileId,
        'name': profileId == null ? name : null,
        'role': role,
        'company': company,
        'bio': bio,
        'sort_order': sortOrder,
      };
}
