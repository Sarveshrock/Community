enum EventVisibility { public, connections, inviteOnly }

extension EventVisibilityX on EventVisibility {
  String get value => switch (this) {
        EventVisibility.inviteOnly => 'invite_only',
        _ => name,
      };

  String get label => switch (this) {
        EventVisibility.public => 'Public',
        EventVisibility.connections => 'Connections',
        EventVisibility.inviteOnly => 'Invite only',
      };

  static EventVisibility fromValue(String? value) => EventVisibility.values
      .firstWhere((e) => e.value == value, orElse: () => EventVisibility.public);
}

enum EventStatus { published, cancelled }

extension EventStatusX on EventStatus {
  String get value => name;

  static EventStatus fromValue(String? value) => EventStatus.values
      .firstWhere((e) => e.value == value, orElse: () => EventStatus.published);
}

/// A Tech & Developer event — spans the whole spec's richer creation flow
/// (Phase 1): audience/registration, informational pricing (no payment
/// processing exists anywhere in this app, so this is display-only, ready
/// for real integration later), and the conditional online/offline/hybrid
/// location fields. Agenda/speakers live in their own entities
/// (`EventAgendaItem`/`EventSpeaker`) since they're one-to-many.
class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.hostId,
    this.hostName,
    this.hostAvatarUrl,
    required this.title,
    this.shortDescription,
    this.description,
    this.eventType = 'community_event',
    this.mode = 'online',
    this.location,
    required this.startsAt,
    this.endsAt,
    this.isAllDay = false,
    this.timezone = 'UTC',
    this.registrationUrl,
    this.coverImageUrl,
    this.meetingPlatform,
    this.meetingUrl,
    this.joiningInstructions,
    this.venueName,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.maxParticipants,
    this.registrationRequired = true,
    this.registrationDeadline,
    this.visibility = EventVisibility.public,
    this.audience = const [],
    this.isFree = true,
    this.price,
    this.currency = 'INR',
    this.whatToBring = const [],
    this.prerequisites,
    this.benefits = const [],
    this.skillLevel,
    this.requiredSoftware = const [],
    this.status = EventStatus.published,
    this.cancellationReason,
    this.tags = const [],
    this.attendeeCount = 0,
  });

  final String id;
  final String hostId;
  final String? hostName;
  final String? hostAvatarUrl;
  final String title;
  final String? shortDescription;
  final String? description;
  final String eventType;
  final String mode;
  final String? location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool isAllDay;
  final String timezone;
  final String? registrationUrl;
  final String? coverImageUrl;

  // Location detail, conditional on `mode`.
  final String? meetingPlatform;
  final String? meetingUrl;
  final String? joiningInstructions;
  final String? venueName;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;

  // Audience & registration.
  final int? maxParticipants;
  final bool registrationRequired;
  final DateTime? registrationDeadline;
  final EventVisibility visibility;
  final List<String> audience;

  // Pricing — informational only (see class doc).
  final bool isFree;
  final double? price;
  final String currency;

  // Requirements & benefits.
  final List<String> whatToBring;
  final String? prerequisites;
  final List<String> benefits;
  final String? skillLevel;
  final List<String> requiredSoftware;

  final EventStatus status;
  final String? cancellationReason;
  final List<String> tags;
  final int attendeeCount;

  bool get isOnline => mode == 'online';
  bool get isOffline => mode == 'offline';
  bool get isHybrid => mode == 'hybrid';
  bool get isCancelled => status == EventStatus.cancelled;
  bool get hasEnded => (endsAt ?? startsAt).isBefore(DateTime.now());
  bool get hasStarted => startsAt.isBefore(DateTime.now());
  bool get registrationClosed =>
      registrationDeadline != null && DateTime.now().isAfter(registrationDeadline!);
  bool get isFull => maxParticipants != null && attendeeCount >= maxParticipants!;

  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    final host = json['host'] as Map<String, dynamic>?;
    return CommunityEvent(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      hostName: host?['full_name'] as String?,
      hostAvatarUrl: host?['avatar_url'] as String?,
      title: json['title'] as String,
      shortDescription: json['short_description'] as String?,
      description: json['description'] as String?,
      eventType: json['event_type'] as String? ?? 'community_event',
      mode: json['mode'] as String? ?? 'online',
      location: json['location'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at'] as String) : null,
      isAllDay: json['is_all_day'] as bool? ?? false,
      timezone: json['timezone'] as String? ?? 'UTC',
      registrationUrl: json['registration_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      meetingPlatform: json['meeting_platform'] as String?,
      meetingUrl: json['meeting_url'] as String?,
      joiningInstructions: json['joining_instructions'] as String?,
      venueName: json['venue_name'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      maxParticipants: (json['max_participants'] as num?)?.toInt(),
      registrationRequired: json['registration_required'] as bool? ?? true,
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.parse(json['registration_deadline'] as String)
          : null,
      visibility: EventVisibilityX.fromValue(json['visibility'] as String?),
      audience: (json['audience'] as List<dynamic>?)?.cast<String>() ?? const [],
      isFree: json['is_free'] as bool? ?? true,
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      whatToBring: (json['what_to_bring'] as List<dynamic>?)?.cast<String>() ?? const [],
      prerequisites: json['prerequisites'] as String?,
      benefits: (json['benefits'] as List<dynamic>?)?.cast<String>() ?? const [],
      skillLevel: json['skill_level'] as String?,
      requiredSoftware: (json['required_software'] as List<dynamic>?)?.cast<String>() ?? const [],
      status: EventStatusX.fromValue(json['status'] as String?),
      cancellationReason: json['cancellation_reason'] as String?,
      tags: (json['event_tags'] as List<dynamic>?)
              ?.map((e) => (e as Map<String, dynamic>)['skills'] as Map<String, dynamic>?)
              .whereType<Map<String, dynamic>>()
              .map((s) => s['name'] as String)
              .toList() ??
          const [],
      attendeeCount: (json['event_attendees'] is List)
          ? (json['event_attendees'] as List).length
          : (json['attendee_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Known event categories (spec section: allow more than the original 6).
/// Kept as a Dart list mirroring the `event_type` Postgres enum
/// (0002_enums.sql + 0042_events_rich_details.sql) — if the enum gains a
/// new value later, add it here too rather than reading pg_enum at runtime,
/// matching how `kPostCategories`/`kNewsCategories` are already handled.
const kEventTypes = <String>[
  'hackathon',
  'workshop',
  'conference',
  'tech_talk',
  'study_session',
  'community_event',
  'meetup',
  'webinar',
  'networking',
  'competition',
  'other',
];

String eventTypeLabel(String value) => switch (value) {
      'tech_talk' => 'Tech Talk',
      'study_session' => 'Study Session',
      'community_event' => 'Community Event',
      _ => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1),
    };

const kEventAudiences = <String>[
  'Students',
  'Developers',
  'Designers',
  'Founders',
  'Professionals',
  'Job seekers',
  'Entrepreneurs',
  'Everyone',
];
