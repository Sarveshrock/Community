import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/connection_repository_impl.dart';
import '../../domain/entities/connection.dart';
import '../../domain/repositories/connection_repository.dart';

final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  return ConnectionRepositoryImpl(supabase);
});

final myConnectionsProvider =
    FutureProvider.family<List<Connection>, ConnectionStatus?>(
        (ref, status) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref
      .watch(connectionRepositoryProvider)
      .getMyConnections(user.id, status: status);
});

final connectionWithProvider =
    FutureProvider.family<Connection?, String>((ref, otherId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref
      .watch(connectionRepositoryProvider)
      .getConnectionBetween(user.id, otherId);
});

/// "Buddies": every accepted connection, each with the viewer's own
/// private pet name (if set) already attached.
final buddiesProvider = FutureProvider<List<Connection>>((ref) {
  return ref.watch(myConnectionsProvider(ConnectionStatus.accepted).future);
});

/// Whether the caller has blocked [otherId] — drives the Block/Unblock
/// toggle on their profile/chat actions.
final isBlockedByMeProvider =
    FutureProvider.family<bool, String>((ref, otherId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;
  return ref.watch(connectionRepositoryProvider).isBlockedByMe(otherId);
});

/// Every profile the caller has blocked — backs the "Blocked users" screen,
/// the fallback way to undo a block for someone no longer reachable from
/// anywhere else in the app.
final blockedUsersProvider = FutureProvider<List<BlockedUser>>((ref) {
  return ref.watch(connectionRepositoryProvider).getBlockedUsers();
});

/// Every pet name the caller has set, keyed by the *other* profile's id.
/// The single source every name-rendering screen in the app should read
/// pet names from — see [getDisplayName].
final myPetNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return {};
  return ref.watch(connectionRepositoryProvider).getMyPetNames(user.id);
});

/// The single formatting rule for how another user's name should render to
/// the current viewer: "Main Name (Pet Name)" when the viewer has privately
/// nicknamed them (Buddies), otherwise just the main name. Every screen
/// that shows a connection's name — profile, chat, team members, search
/// results, connection cards, ... — should call this instead of formatting
/// `full_name`/`display_name` directly, so pet names don't need duplicated
/// (and easy-to-miss) logic per screen.
///
/// [mainName] may be null/empty while a profile is still loading; this
/// falls back to a generic label exactly like the individual entities'
/// own `displayName` getters already do, so nothing looks different while
/// pet names are unset.
String getDisplayName(
  WidgetRef ref, {
  required String profileId,
  required String? mainName,
}) {
  final petName = ref.watch(myPetNamesProvider).valueOrNull?[profileId];
  return formatConnectionDisplayName(mainName: mainName, petName: petName);
}

/// The pure "Main Name (Pet Name)" / "Main Name" formatting rule behind
/// [getDisplayName], pulled out so it's unit-testable without a widget
/// harness — [getDisplayName] is just this plus the actual privacy-scoped
/// lookup. Never renders empty parentheses: a null/empty [petName] means
/// no pet name is set, not "()".
String formatConnectionDisplayName(
    {required String? mainName, required String? petName}) {
  final name = (mainName?.isNotEmpty ?? false) ? mainName! : 'Community member';
  return (petName != null && petName.isNotEmpty) ? '$name ($petName)' : name;
}

class ConnectionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _invalidateAll() {
    ref.invalidate(myConnectionsProvider);
    ref.invalidate(connectionWithProvider);
    ref.invalidate(buddiesProvider);
    ref.invalidate(myPetNamesProvider);
    ref.invalidate(isBlockedByMeProvider);
    ref.invalidate(blockedUsersProvider);
  }

  Future<bool> sendRequest(String receiverId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(connectionRepositoryProvider).sendRequest(receiverId));
    state = result;
    if (!result.hasError) {
      _invalidateAll();
      ref
          .read(analyticsServiceProvider)
          .log(AnalyticsEvents.connectionSent, {'receiver_id': receiverId});
    }
    return !result.hasError;
  }

  Future<bool> respond(String connectionId, {required bool accept}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(connectionRepositoryProvider)
          .respondToRequest(connectionId, accept: accept),
    );
    state = result;
    if (!result.hasError) {
      _invalidateAll();
      if (accept) {
        ref.read(analyticsServiceProvider).log(
            AnalyticsEvents.connectionAccepted,
            {'connection_id': connectionId});
      }
    }
    return !result.hasError;
  }

  Future<bool> cancel(String connectionId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(connectionRepositoryProvider).cancelRequest(connectionId));
    state = result;
    if (!result.hasError) _invalidateAll();
    return !result.hasError;
  }

  Future<bool> blockUser(String userId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(connectionRepositoryProvider).blockUser(userId));
    state = result;
    if (!result.hasError) _invalidateAll();
    return !result.hasError;
  }

  /// Undoes a block — the piece that was missing entirely: [blockUser] was
  /// always reachable from the UI, but nothing ever called the matching
  /// [ConnectionRepository.unblockUser], which had existed unused since the
  /// repository was written. Restores messaging/connecting between the two
  /// profiles immediately (both gated by `is_blocked()` server-side).
  Future<bool> unblockUser(String userId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(connectionRepositoryProvider).unblockUser(userId));
    state = result;
    if (!result.hasError) _invalidateAll();
    return !result.hasError;
  }

  /// "Disconnect" (Buddies spec section 4). Removes the connection for
  /// both parties and, via the DB's `on delete cascade`, whatever pet name
  /// either side had set for it.
  Future<bool> disconnect(String connectionId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(connectionRepositoryProvider).removeConnection(connectionId));
    state = result;
    if (!result.hasError) _invalidateAll();
    return !result.hasError;
  }

  Future<bool> setPetName(String connectionId, String nickname) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(connectionRepositoryProvider)
          .setPetName(connectionId, nickname),
    );
    state = result;
    if (!result.hasError) _invalidateAll();
    return !result.hasError;
  }

  Future<bool> removePetName(String connectionId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(connectionRepositoryProvider).removePetName(connectionId));
    state = result;
    if (!result.hasError) _invalidateAll();
    return !result.hasError;
  }
}

final connectionControllerProvider =
    AsyncNotifierProvider<ConnectionController, void>(ConnectionController.new);
