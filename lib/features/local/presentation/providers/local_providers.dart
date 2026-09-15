import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/local_repository_impl.dart';
import '../../domain/entities/local_entities.dart';
import '../../domain/repositories/local_repository.dart';

final localRepositoryProvider = Provider<LocalRepository>((ref) {
  return LocalRepositoryImpl(supabase);
});

final myLocalProfileProvider = FutureProvider<LocalProfile?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(localRepositoryProvider).getMyLocalProfile(user.id);
});

final localCandidatesProvider = FutureProvider<List<LocalCandidate>>((ref) {
  return ref.watch(localRepositoryProvider).getCandidates();
});

final localConnectionWithProvider =
    FutureProvider.family<LocalConnection?, String>((ref, otherId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref
      .watch(localRepositoryProvider)
      .getLocalConnectionBetween(user.id, otherId);
});

final myLocalConnectionsProvider =
    FutureProvider.family<List<LocalConnection>, LocalConnectionStatus?>(
        (ref, status) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref
      .watch(localRepositoryProvider)
      .getMyLocalConnections(user.id, status: status);
});

final meetupsForConnectionProvider =
    FutureProvider.family<List<MeetupSuggestion>, String>(
        (ref, localConnectionId) {
  return ref
      .watch(localRepositoryProvider)
      .getMeetupsForConnection(localConnectionId);
});

class LocalController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> saveLocalProfile(Map<String, dynamic> data,
      {required List<String> activities,
      required List<String> interests}) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;
    state = const AsyncLoading();
    final repo = ref.read(localRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      await repo.upsertLocalProfile(user.id, data);
      await repo.setLocalPreferences(user.id,
          activities: activities, interests: interests);
    });
    state = result;
    if (!result.hasError) {
      ref.invalidate(myLocalProfileProvider);
      ref.invalidate(localCandidatesProvider);
    }
    return !result.hasError;
  }

  Future<bool> sendRequest(String receiverId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(localRepositoryProvider).sendLocalRequest(receiverId));
    state = result;
    if (!result.hasError) {
      ref.invalidate(localConnectionWithProvider);
      ref.invalidate(localCandidatesProvider);
      ref.read(analyticsServiceProvider).log(
          AnalyticsEvents.localConnectionRequest, {'receiver_id': receiverId});
    }
    return !result.hasError;
  }

  Future<bool> respondToRequest(String connectionId,
      {required bool accept}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(localRepositoryProvider)
          .respondToLocalRequest(connectionId, accept: accept),
    );
    state = result;
    if (!result.hasError) {
      ref.invalidate(myLocalConnectionsProvider);
      ref.invalidate(localConnectionWithProvider);
    }
    return !result.hasError;
  }

  Future<bool> suggestMeetup(
      String localConnectionId, Map<String, dynamic> data) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(localRepositoryProvider)
          .suggestMeetup({'local_connection_id': localConnectionId, ...data}),
    );
    state = result;
    if (!result.hasError) {
      ref.invalidate(meetupsForConnectionProvider(localConnectionId));
      ref.read(analyticsServiceProvider).log(AnalyticsEvents.meetupSuggested,
          {'local_connection_id': localConnectionId});
    }
    return !result.hasError;
  }

  Future<bool> respondToMeetup(String localConnectionId, String meetupId,
      {required bool accept}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(localRepositoryProvider)
          .respondToMeetup(meetupId, accept: accept),
    );
    state = result;
    if (!result.hasError) {
      ref.invalidate(meetupsForConnectionProvider(localConnectionId));
      if (accept) {
        ref
            .read(analyticsServiceProvider)
            .log(AnalyticsEvents.meetupAccepted, {'meetup_id': meetupId});
      }
    }
    return !result.hasError;
  }
}

final localControllerProvider =
    AsyncNotifierProvider<LocalController, void>(LocalController.new);
