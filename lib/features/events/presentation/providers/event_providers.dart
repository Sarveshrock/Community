import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/event_repository_impl.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_agenda_item.dart';
import '../../domain/entities/event_join_request.dart';
import '../../domain/entities/event_speaker.dart';
import '../../domain/repositories/event_repository.dart';

export '../../domain/entities/event.dart';
export '../../domain/entities/event_agenda_item.dart';
export '../../domain/entities/event_join_request.dart';
export '../../domain/entities/event_speaker.dart';
export '../../domain/event_action_state.dart';
export '../../domain/repositories/event_repository.dart' show EventFilters;

final eventRepositoryProvider =
    Provider<EventRepository>((ref) => EventRepositoryImpl(supabase));

final eventFiltersProvider = StateProvider<EventFilters>((ref) => const EventFilters());

final eventsListProvider = FutureProvider<List<CommunityEvent>>((ref) {
  final filters = ref.watch(eventFiltersProvider);
  return ref.watch(eventRepositoryProvider).listEvents(filters: filters);
});

/// Upcoming events for one community — independent of [eventFiltersProvider]
/// so viewing a Community Detail page never disturbs the global Events tab's
/// filter state.
final communityEventsProvider = FutureProvider.family<List<CommunityEvent>, String>((ref, communityId) {
  return ref.watch(eventRepositoryProvider).listEvents(filters: EventFilters(communityId: communityId));
});

final eventDetailProvider =
    FutureProvider.family<CommunityEvent, String>((ref, id) {
  return ref.watch(eventRepositoryProvider).getEvent(id);
});

final isAttendingEventProvider =
    FutureProvider.family<bool, String>((ref, eventId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;
  return ref.watch(eventRepositoryProvider).isAttending(eventId, user.id);
});

final eventAgendaProvider =
    FutureProvider.family<List<EventAgendaItem>, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).listAgendaItems(eventId);
});

final eventSpeakersProvider =
    FutureProvider.family<List<EventSpeaker>, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).listSpeakers(eventId);
});

/// The caller's own join request for one (invite-only) event, if any —
/// drives the "Pending approval" CTA state.
final myEventJoinRequestProvider =
    FutureProvider.family<EventJoinRequest?, String>((ref, eventId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(eventRepositoryProvider).myJoinRequest(eventId);
});

/// Host-only: pending join requests for one event — backs the small
/// "Manage requests" affordance on the organizer's own event.
final eventJoinRequestsProvider =
    FutureProvider.family<List<EventJoinRequest>, String>((ref, eventId) {
  return ref.watch(eventRepositoryProvider).listJoinRequests(eventId);
});

class EventController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns 'registered' or 'requested' on success, null on failure — the
  /// caller shows the right confirmation copy for whichever happened.
  Future<String?> joinEvent(String eventId) async {
    state = const AsyncLoading();
    final result =
        await AsyncValue.guard(() => ref.read(eventRepositoryProvider).joinEvent(eventId));
    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    if (!result.hasError) {
      ref.invalidate(isAttendingEventProvider(eventId));
      ref.invalidate(eventDetailProvider(eventId));
      ref.invalidate(myEventJoinRequestProvider(eventId));
    }
    return result.valueOrNull;
  }

  Future<bool> cancelRsvp(String eventId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(eventRepositoryProvider).cancelRsvp(eventId));
    state = result;
    if (!result.hasError) {
      ref.invalidate(isAttendingEventProvider(eventId));
      ref.invalidate(eventDetailProvider(eventId));
    }
    return !result.hasError;
  }

  Future<CommunityEvent?> createEvent(
    Map<String, dynamic> data, {
    List<String> tagSkillIds = const [],
    List<EventAgendaItem> agendaItems = const [],
    List<EventSpeaker> speakers = const [],
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(eventRepositoryProvider).createEvent(
            data,
            tagSkillIds: tagSkillIds,
            agendaItems: agendaItems,
            speakers: speakers,
          ),
    );
    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    if (!result.hasError) ref.invalidate(eventsListProvider);
    return result.valueOrNull;
  }

  Future<bool> updateEvent(
    String id,
    Map<String, dynamic> changes, {
    List<String>? tagSkillIds,
    List<EventAgendaItem>? agendaItems,
    List<EventSpeaker>? speakers,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(eventRepositoryProvider).updateEvent(
          id,
          changes,
          tagSkillIds: tagSkillIds,
          agendaItems: agendaItems,
          speakers: speakers,
        ));
    state = result;
    if (!result.hasError) {
      ref.invalidate(eventDetailProvider(id));
      ref.invalidate(eventsListProvider);
    }
    return !result.hasError;
  }

  Future<bool> cancelEvent(String id, {String? reason}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(eventRepositoryProvider).cancelEvent(id, reason: reason));
    state = result;
    if (!result.hasError) {
      ref.invalidate(eventDetailProvider(id));
      ref.invalidate(eventsListProvider);
    }
    return !result.hasError;
  }

  Future<String?> uploadCoverImage(String eventId, List<int> bytes, String fileExt) async {
    try {
      return await ref.read(eventRepositoryProvider).uploadCoverImage(eventId, bytes, fileExt);
    } catch (_) {
      return null;
    }
  }

  Future<bool> respondToJoinRequest(String requestId, String eventId, {required bool accept}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(eventRepositoryProvider).respondToJoinRequest(requestId, accept: accept));
    state = result;
    if (!result.hasError) {
      ref.invalidate(eventJoinRequestsProvider(eventId));
      ref.invalidate(eventDetailProvider(eventId));
    }
    return !result.hasError;
  }
}

final eventControllerProvider =
    AsyncNotifierProvider<EventController, void>(EventController.new);
