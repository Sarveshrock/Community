/// Result row from the privacy-safe `get_local_candidates()` database
/// function (spec section 51) — distance buckets only, never coordinates.
class LocalCandidate {
  const LocalCandidate({
    required this.profileId,
    required this.displayName,
    this.avatarUrl,
    required this.distanceBucket,
    this.city,
    this.area,
    this.bio,
  });

  final String profileId;
  final String displayName;
  final String? avatarUrl;
  final String distanceBucket;
  final String? city;
  final String? area;
  final String? bio;

  factory LocalCandidate.fromJson(Map<String, dynamic> json) => LocalCandidate(
        profileId: json['profile_id'] as String,
        displayName: json['display_name'] as String? ?? 'Someone nearby',
        avatarUrl: json['avatar_url'] as String?,
        distanceBucket:
            json['approximate_distance_bucket'] as String? ?? 'nearby',
        city: json['city'] as String?,
        area: json['area'] as String?,
        bio: json['bio'] as String?,
      );
}

class LocalProfile {
  const LocalProfile({
    required this.profileId,
    this.enabled = false,
    this.approximateCity,
    this.approximateArea,
    this.preferredRadiusKm = 5,
    this.bio,
    this.activityPreferences = const [],
    this.interestPreferences = const [],
  });

  final String profileId;
  final bool enabled;
  final String? approximateCity;
  final String? approximateArea;
  final int preferredRadiusKm;
  final String? bio;
  final List<String> activityPreferences;
  final List<String> interestPreferences;

  factory LocalProfile.fromJson(Map<String, dynamic> json,
      {List<String> activities = const [], List<String> interests = const []}) {
    return LocalProfile(
      profileId: json['profile_id'] as String,
      enabled: json['enabled'] as bool? ?? false,
      approximateCity: json['approximate_city'] as String?,
      approximateArea: json['approximate_area'] as String?,
      preferredRadiusKm: (json['preferred_radius_km'] as num?)?.toInt() ?? 5,
      bio: json['bio'] as String?,
      activityPreferences: activities,
      interestPreferences: interests,
    );
  }
}

enum LocalConnectionStatus { pending, accepted, declined, cancelled, blocked }

extension LocalConnectionStatusX on LocalConnectionStatus {
  String get value => name;
  static LocalConnectionStatus fromValue(String? value) {
    return LocalConnectionStatus.values.firstWhere((e) => e.value == value,
        orElse: () => LocalConnectionStatus.pending);
  }
}

class LocalConnection {
  const LocalConnection({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.status,
    this.otherName,
    this.otherAvatarUrl,
  });

  final String id;
  final String requesterId;
  final String receiverId;
  final LocalConnectionStatus status;
  final String? otherName;
  final String? otherAvatarUrl;

  String otherProfileId(String myId) =>
      requesterId == myId ? receiverId : requesterId;

  factory LocalConnection.fromJson(Map<String, dynamic> json,
      {required String viewerId}) {
    final requesterId = json['requester_id'] as String;
    final receiverId = json['receiver_id'] as String;
    final otherId = requesterId == viewerId ? receiverId : requesterId;
    final otherKey = requesterId == otherId ? 'requester' : 'receiver';
    final otherProfile = json['${otherKey}_profile'] as Map<String, dynamic>?;
    return LocalConnection(
      id: json['id'] as String,
      requesterId: requesterId,
      receiverId: receiverId,
      status: LocalConnectionStatusX.fromValue(json['status'] as String?),
      otherName: otherProfile?['full_name'] as String?,
      otherAvatarUrl: otherProfile?['avatar_url'] as String?,
    );
  }
}

class MeetupSuggestion {
  const MeetupSuggestion({
    required this.id,
    required this.localConnectionId,
    required this.suggestedBy,
    required this.activityType,
    this.suggestedArea,
    this.suggestedPlaceName,
    this.suggestedAt,
    this.message,
    this.status = 'pending',
  });

  final String id;
  final String localConnectionId;
  final String suggestedBy;
  final String activityType;
  final String? suggestedArea;
  final String? suggestedPlaceName;
  final DateTime? suggestedAt;
  final String? message;
  final String status;

  factory MeetupSuggestion.fromJson(Map<String, dynamic> json) =>
      MeetupSuggestion(
        id: json['id'] as String,
        localConnectionId: json['local_connection_id'] as String,
        suggestedBy: json['suggested_by'] as String,
        activityType: json['activity_type'] as String,
        suggestedArea: json['suggested_area'] as String?,
        suggestedPlaceName: json['suggested_place_name'] as String?,
        suggestedAt: json['suggested_at'] != null
            ? DateTime.parse(json['suggested_at'] as String)
            : null,
        message: json['message'] as String?,
        status: json['status'] as String? ?? 'pending',
      );
}
