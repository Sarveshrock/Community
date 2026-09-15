/// One session in an event's schedule (`event_agenda_items`). The speaker
/// is either a real Communeo profile (`speakerProfileId`) or free text
/// (`speakerName`) for someone without one — never both required.
class EventAgendaItem {
  const EventAgendaItem({
    required this.id,
    required this.eventId,
    required this.title,
    this.description,
    required this.startsAt,
    this.endsAt,
    this.speakerProfileId,
    this.speakerProfileName,
    this.speakerName,
    this.room,
    this.sortOrder = 0,
  });

  final String id;
  final String eventId;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? speakerProfileId;
  final String? speakerProfileName;
  final String? speakerName;
  final String? room;
  final int sortOrder;

  /// The name to display, whichever source it came from.
  String? get speakerDisplayName => speakerProfileName ?? speakerName;

  factory EventAgendaItem.fromJson(Map<String, dynamic> json) {
    final speaker = json['speaker'] as Map<String, dynamic>?;
    return EventAgendaItem(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at'] as String) : null,
      speakerProfileId: json['speaker_profile_id'] as String?,
      speakerProfileName: speaker?['full_name'] as String?,
      speakerName: json['speaker_name'] as String?,
      room: json['room'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson(String eventId) => {
        'event_id': eventId,
        'title': title,
        'description': description,
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'speaker_profile_id': speakerProfileId,
        'speaker_name': speakerProfileId == null ? speakerName : null,
        'room': room,
        'sort_order': sortOrder,
      };
}
