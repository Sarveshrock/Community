enum ConnectionStatus { pending, accepted, declined, cancelled, blocked }

extension ConnectionStatusX on ConnectionStatus {
  String get value => name;

  static ConnectionStatus fromValue(String? value) {
    return ConnectionStatus.values.firstWhere((e) => e.value == value,
        orElse: () => ConnectionStatus.pending);
  }
}

class Connection {
  const Connection({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.otherProfileName,
    this.otherProfileAvatar,
    this.otherProfileHeadline,
    this.otherProfileLocation,
    this.otherProfileInterests = const [],
    this.otherProfileBio,
    this.otherProfileUpdatedAt,
    this.petName,
  });

  final String id;
  final String requesterId;
  final String receiverId;
  final ConnectionStatus status;
  final DateTime createdAt;
  final String? otherProfileName;
  final String? otherProfileAvatar;
  final String? otherProfileHeadline;

  /// "City, Country" (or just whichever half is set) — real profile data,
  /// not shown on Buddies before this card redesign.
  final String? otherProfileLocation;

  /// The other profile's interests, for the Buddies tag row. Comes back
  /// empty (not null) if they've set none, or if `profile_interests_select`
  /// RLS hides them (not self, not professional_discoverable) — either way
  /// the UI should just render no tags, never placeholder ones.
  final List<String> otherProfileInterests;

  /// The other profile's "About" text, shown as the card's short bio.
  final String? otherProfileBio;

  /// There is no presence/last-seen system anywhere in this app — this is
  /// the best genuine proxy available: `profiles.updated_at`, bumped by the
  /// existing `handle_updated_at()` trigger on every profile write. It's an
  /// approximation (editing a profile isn't the same as being active right
  /// now), not real presence — see [BuddyPresence] for how it's turned
  /// into an Online/Offline label instead of ever hardcoding "Online".
  final DateTime? otherProfileUpdatedAt;

  /// The *viewer's own* private nickname for this connection (Buddies) —
  /// never the other party's nickname for them; `connection_nicknames`' RLS
  /// only ever returns the caller's own row, so this is safe by construction.
  final String? petName;

  String otherProfileId(String myId) =>
      requesterId == myId ? receiverId : requesterId;
  bool isIncoming(String myId) => receiverId == myId;

  /// "Shivam (Shivu)" when a pet name is set, otherwise just "Shivam".
  String displayName({String fallback = 'Community member'}) {
    final name = otherProfileName ?? fallback;
    return (petName?.isNotEmpty ?? false) ? '$name ($petName)' : name;
  }

  factory Connection.fromJson(Map<String, dynamic> json,
      {required String viewerId}) {
    final requesterId = json['requester_id'] as String;
    final receiverId = json['receiver_id'] as String;
    final otherId = requesterId == viewerId ? receiverId : requesterId;
    final otherKey = requesterId == otherId ? 'requester' : 'receiver';
    final otherProfile = json['${otherKey}_profile'] as Map<String, dynamic>?;
    final nicknameRows = json['connection_nicknames'] as List<dynamic>?;
    final petName = nicknameRows != null && nicknameRows.isNotEmpty
        ? (nicknameRows.first as Map<String, dynamic>)['nickname'] as String?
        : null;

    final city = otherProfile?['city'] as String?;
    final country = otherProfile?['country'] as String?;
    final location = [
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country,
    ].join(', ');

    final interestRows = otherProfile?['profile_interests'] as List<dynamic>?;
    final interests = interestRows
            ?.map((e) =>
                ((e as Map<String, dynamic>)['interests']
                    as Map<String, dynamic>?)?['name'] as String?)
            .whereType<String>()
            .toList() ??
        const <String>[];

    return Connection(
      id: json['id'] as String,
      requesterId: requesterId,
      receiverId: receiverId,
      status: ConnectionStatusX.fromValue(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      otherProfileName: otherProfile?['full_name'] as String?,
      otherProfileAvatar: otherProfile?['avatar_url'] as String?,
      otherProfileHeadline: otherProfile?['current_role'] as String?,
      otherProfileLocation: location.isEmpty ? null : location,
      otherProfileInterests: interests,
      otherProfileBio: otherProfile?['bio'] as String?,
      otherProfileUpdatedAt: otherProfile?['updated_at'] != null
          ? DateTime.parse(otherProfile!['updated_at'] as String)
          : null,
      petName: petName,
    );
  }
}

/// Derives an Online/Offline label from [Connection.otherProfileUpdatedAt] —
/// the app's only real proxy for activity, in the absence of any presence or
/// last-seen system. Never a hardcoded "Online".
class BuddyPresence {
  const BuddyPresence({required this.isOnline, required this.label});

  final bool isOnline;
  final String label;

  static const _onlineWindow = Duration(minutes: 15);

  factory BuddyPresence.fromUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) return const BuddyPresence(isOnline: false, label: 'Offline');
    final elapsed = DateTime.now().difference(updatedAt);
    if (elapsed <= _onlineWindow) {
      return const BuddyPresence(isOnline: true, label: 'Online');
    }
    final String ago;
    if (elapsed.inDays >= 1) {
      ago = '${elapsed.inDays}d';
    } else if (elapsed.inHours >= 1) {
      ago = '${elapsed.inHours}h';
    } else {
      ago = '${elapsed.inMinutes.clamp(1, 59)}m';
    }
    return BuddyPresence(isOnline: false, label: 'Offline · $ago');
  }
}

/// A profile the caller has blocked — backs the "Blocked users" management
/// screen, the only reliable way to undo an accidental block once the
/// blocked person is no longer reachable from anywhere else in the app
/// (no shared conversation, no mutual connection card to find a toggle on).
class BlockedUser {
  const BlockedUser({
    required this.profileId,
    this.fullName,
    this.avatarUrl,
    this.headline,
  });

  final String profileId;
  final String? fullName;
  final String? avatarUrl;
  final String? headline;

  String get displayName =>
      (fullName?.isNotEmpty ?? false) ? fullName! : 'Community member';

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return BlockedUser(
      profileId: json['blocked_id'] as String,
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      headline: profile?['current_role'] as String?,
    );
  }
}
