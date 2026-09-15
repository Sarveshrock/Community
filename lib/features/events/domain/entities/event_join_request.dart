/// One request to join an invite-only event (`event_join_requests`) —
/// mirrors `hackathon_team_join_requests`'s shape/lifecycle exactly, just
/// scoped to events instead of hackathon teams.
enum EventJoinRequestStatus { pending, accepted, rejected, cancelled }

extension EventJoinRequestStatusX on EventJoinRequestStatus {
  String get value => name;

  static EventJoinRequestStatus fromValue(String? value) =>
      EventJoinRequestStatus.values.firstWhere((e) => e.value == value,
          orElse: () => EventJoinRequestStatus.pending);
}

class EventJoinRequest {
  const EventJoinRequest({
    required this.id,
    required this.eventId,
    required this.requesterId,
    this.requesterName,
    this.requesterAvatarUrl,
    required this.status,
    this.message,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final String requesterId;
  final String? requesterName;
  final String? requesterAvatarUrl;
  final EventJoinRequestStatus status;
  final String? message;
  final DateTime createdAt;

  factory EventJoinRequest.fromJson(Map<String, dynamic> json) {
    final requester = json['requester'] as Map<String, dynamic>?;
    return EventJoinRequest(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      requesterId: json['requester_id'] as String,
      requesterName: requester?['full_name'] as String?,
      requesterAvatarUrl: requester?['avatar_url'] as String?,
      status: EventJoinRequestStatusX.fromValue(json['status'] as String?),
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
