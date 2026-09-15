import '../entities/event.dart';
import '../entities/event_agenda_item.dart';
import '../entities/event_join_request.dart';
import '../entities/event_speaker.dart';

class EventFilters {
  const EventFilters({
    this.query,
    this.eventType,
    this.mode,
    this.freeOnly = false,
    this.upcomingOnly = true,
    this.communityId,
  });

  final String? query;
  final String? eventType;
  final String? mode;
  final bool freeOnly;

  /// true = only events that haven't ended yet (the default feed); false =
  /// past events, for a "Past" filter toggle.
  final bool upcomingOnly;

  /// Scopes to one community's events (`events.community_id`, already an
  /// existing column — see the Community Detail page's "Upcoming Events"
  /// section). Null = the unscoped global feed.
  final String? communityId;

  EventFilters copyWith({
    String? query,
    String? eventType,
    String? mode,
    bool? freeOnly,
    bool? upcomingOnly,
    String? communityId,
  }) {
    return EventFilters(
      query: query ?? this.query,
      eventType: eventType ?? this.eventType,
      mode: mode ?? this.mode,
      freeOnly: freeOnly ?? this.freeOnly,
      upcomingOnly: upcomingOnly ?? this.upcomingOnly,
      communityId: communityId ?? this.communityId,
    );
  }
}

abstract class EventRepository {
  Future<List<CommunityEvent>> listEvents({EventFilters filters = const EventFilters()});

  /// Goes through the `get_event` SECURITY DEFINER function so sensitive
  /// fields (meeting link, exact address) come back null unless the caller
  /// is authorized — see 0042_events_rich_details.sql.
  Future<CommunityEvent> getEvent(String id);

  Future<bool> isAttending(String eventId, String profileId);

  /// Returns 'registered' or 'requested' (invite-only) — see join_event().
  Future<String> joinEvent(String eventId);
  Future<void> cancelRsvp(String eventId);

  Future<CommunityEvent> createEvent(
    Map<String, dynamic> data, {
    List<String> tagSkillIds = const [],
    List<EventAgendaItem> agendaItems = const [],
    List<EventSpeaker> speakers = const [],
  });

  /// `changes` always applies. `tagSkillIds`/`agendaItems`/`speakers`, when
  /// non-null, fully replace the event's existing set (delete-then-insert,
  /// same as `setSkills`/`setInterests`) — omit any of them to leave that
  /// part of the event untouched.
  Future<void> updateEvent(
    String id,
    Map<String, dynamic> changes, {
    List<String>? tagSkillIds,
    List<EventAgendaItem>? agendaItems,
    List<EventSpeaker>? speakers,
  });
  Future<void> cancelEvent(String id, {String? reason});

  Future<String> uploadCoverImage(String eventId, List<int> bytes, String fileExt);

  Future<List<EventAgendaItem>> listAgendaItems(String eventId);
  Future<List<EventSpeaker>> listSpeakers(String eventId);

  /// The caller's own pending/accepted/rejected request for an invite-only
  /// event, or null if they never asked.
  Future<EventJoinRequest?> myJoinRequest(String eventId);

  /// Host-only: every join request for one of their events.
  Future<List<EventJoinRequest>> listJoinRequests(String eventId);
  Future<void> respondToJoinRequest(String requestId, {required bool accept});
}
