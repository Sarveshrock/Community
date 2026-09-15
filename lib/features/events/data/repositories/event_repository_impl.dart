import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_agenda_item.dart';
import '../../domain/entities/event_join_request.dart';
import '../../domain/entities/event_speaker.dart';
import '../../domain/repositories/event_repository.dart';

class EventRepositoryImpl implements EventRepository {
  EventRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _listSelect =
      '*, host:profiles!events_host_id_fkey(full_name, avatar_url), '
      'event_attendees(profile_id), event_tags(skills(name))';

  // event_private_details is embedded too: RLS on that table means it
  // simply comes back null/absent for a caller who isn't the host, an
  // admin, or an already-registered attendee — the same "empty embed = no
  // access" pattern connection_nicknames already relies on, so the exact
  // same select works for both the public list and the detail fetch.
  static const _detailSelect =
      '$_listSelect, event_private_details(meeting_url, joining_instructions, address, pincode)';

  CommunityEvent _fromRow(Map<String, dynamic> row) {
    final private = row['event_private_details'];
    final privateMap = private is List
        ? (private.isNotEmpty ? private.first as Map<String, dynamic> : null)
        : private as Map<String, dynamic>?;
    return CommunityEvent.fromJson({...row, ...?privateMap});
  }

  @override
  Future<List<CommunityEvent>> listEvents({EventFilters filters = const EventFilters()}) async {
    try {
      var query = _client.from(Tables.events).select(_listSelect);

      if (filters.eventType != null) query = query.eq('event_type', filters.eventType!);
      if (filters.mode != null) query = query.eq('mode', filters.mode!);
      if (filters.freeOnly) query = query.eq('is_free', true);
      if (filters.communityId != null) query = query.eq('community_id', filters.communityId!);
      if (filters.query != null && filters.query!.isNotEmpty) {
        query = query.or('title.ilike.%${filters.query}%,short_description.ilike.%${filters.query}%');
      }
      if (filters.upcomingOnly) {
        query = query.gte('starts_at', DateTime.now().toIso8601String());
      } else {
        query = query.lt('starts_at', DateTime.now().toIso8601String());
      }

      final data = await query
          .neq('status', 'cancelled')
          .order('starts_at', ascending: filters.upcomingOnly)
          .limit(50);
      return (data as List).map((e) => _fromRow(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<CommunityEvent> getEvent(String id) async {
    try {
      final data = await _client.from(Tables.events).select(_detailSelect).eq('id', id).single();
      return _fromRow(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<bool> isAttending(String eventId, String profileId) async {
    try {
      final data = await _client
          .from(Tables.eventAttendees)
          .select('profile_id')
          .eq('event_id', eventId)
          .eq('profile_id', profileId)
          .maybeSingle();
      return data != null;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> joinEvent(String eventId) async {
    try {
      final result = await _client.rpc('join_event', params: {'p_event_id': eventId});
      return result as String;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> cancelRsvp(String eventId) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client
          .from(Tables.eventAttendees)
          .delete()
          .eq('event_id', eventId)
          .eq('profile_id', myId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<CommunityEvent> createEvent(
    Map<String, dynamic> data, {
    List<String> tagSkillIds = const [],
    List<EventAgendaItem> agendaItems = const [],
    List<EventSpeaker> speakers = const [],
  }) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final privateFields = <String, dynamic>{
        for (final key in ['meeting_url', 'joining_instructions', 'address', 'pincode'])
          if (data.containsKey(key)) key: data[key],
      };
      final publicFields = {...data}
        ..removeWhere((key, _) => privateFields.containsKey(key));

      final inserted = await _client
          .from(Tables.events)
          .insert({...publicFields, 'host_id': myId})
          .select()
          .single();
      final eventId = inserted['id'] as String;

      if (privateFields.isNotEmpty && privateFields.values.any((v) => v != null)) {
        await _client
            .from(Tables.eventPrivateDetails)
            .insert({'event_id': eventId, ...privateFields});
      }
      if (tagSkillIds.isNotEmpty) {
        await _client.from(Tables.eventTags).insert([
          for (final skillId in tagSkillIds) {'event_id': eventId, 'skill_id': skillId},
        ]);
      }
      if (agendaItems.isNotEmpty) {
        await _client
            .from(Tables.eventAgendaItems)
            .insert([for (final a in agendaItems) a.toInsertJson(eventId)]);
      }
      if (speakers.isNotEmpty) {
        await _client
            .from(Tables.eventSpeakers)
            .insert([for (final s in speakers) s.toInsertJson(eventId)]);
      }

      return await getEvent(eventId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> updateEvent(
    String id,
    Map<String, dynamic> changes, {
    List<String>? tagSkillIds,
    List<EventAgendaItem>? agendaItems,
    List<EventSpeaker>? speakers,
  }) async {
    try {
      final privateFields = <String, dynamic>{
        for (final key in ['meeting_url', 'joining_instructions', 'address', 'pincode'])
          if (changes.containsKey(key)) key: changes[key],
      };
      final publicFields = {...changes}
        ..removeWhere((key, _) => privateFields.containsKey(key));

      if (publicFields.isNotEmpty) {
        await _client.from(Tables.events).update(publicFields).eq('id', id);
      }
      if (privateFields.isNotEmpty) {
        await _client
            .from(Tables.eventPrivateDetails)
            .upsert({'event_id': id, ...privateFields});
      }
      if (tagSkillIds != null) {
        await _client.from(Tables.eventTags).delete().eq('event_id', id);
        if (tagSkillIds.isNotEmpty) {
          await _client
              .from(Tables.eventTags)
              .insert([for (final skillId in tagSkillIds) {'event_id': id, 'skill_id': skillId}]);
        }
      }
      if (agendaItems != null) {
        await _client.from(Tables.eventAgendaItems).delete().eq('event_id', id);
        if (agendaItems.isNotEmpty) {
          await _client
              .from(Tables.eventAgendaItems)
              .insert([for (final a in agendaItems) a.toInsertJson(id)]);
        }
      }
      if (speakers != null) {
        await _client.from(Tables.eventSpeakers).delete().eq('event_id', id);
        if (speakers.isNotEmpty) {
          await _client
              .from(Tables.eventSpeakers)
              .insert([for (final s in speakers) s.toInsertJson(id)]);
        }
      }
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> cancelEvent(String id, {String? reason}) async {
    try {
      await _client.rpc('cancel_event', params: {'p_event_id': id, 'p_reason': reason});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> uploadCoverImage(String eventId, List<int> bytes, String fileExt) async {
    try {
      final path = 'events/$eventId/cover.$fileExt';
      await _client.storage.from(StorageBuckets.communityMedia).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from(StorageBuckets.communityMedia).getPublicUrl(path);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<EventAgendaItem>> listAgendaItems(String eventId) async {
    try {
      final data = await _client
          .from(Tables.eventAgendaItems)
          .select('*, speaker:profiles!event_agenda_items_speaker_profile_id_fkey(full_name)')
          .eq('event_id', eventId)
          .order('sort_order');
      return (data as List).map((e) => EventAgendaItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<EventSpeaker>> listSpeakers(String eventId) async {
    try {
      final data = await _client
          .from(Tables.eventSpeakers)
          .select('*, profile:profiles!event_speakers_profile_id_fkey(full_name, avatar_url)')
          .eq('event_id', eventId)
          .order('sort_order');
      return (data as List).map((e) => EventSpeaker.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<EventJoinRequest?> myJoinRequest(String eventId) async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return null;
      final data = await _client
          .from(Tables.eventJoinRequests)
          .select('*, requester:profiles!event_join_requests_requester_id_fkey(full_name, avatar_url)')
          .eq('event_id', eventId)
          .eq('requester_id', myId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data == null ? null : EventJoinRequest.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<EventJoinRequest>> listJoinRequests(String eventId) async {
    try {
      final data = await _client
          .from(Tables.eventJoinRequests)
          .select('*, requester:profiles!event_join_requests_requester_id_fkey(full_name, avatar_url)')
          .eq('event_id', eventId)
          .eq('status', 'pending')
          .order('created_at');
      return (data as List).map((e) => EventJoinRequest.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> respondToJoinRequest(String requestId, {required bool accept}) async {
    try {
      await _client.rpc('respond_to_event_join_request',
          params: {'p_request_id': requestId, 'p_accept': accept});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
