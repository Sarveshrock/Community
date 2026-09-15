import '../entities/connection.dart';

abstract class ConnectionRepository {
  Future<List<Connection>> getMyConnections(String myId,
      {ConnectionStatus? status});
  Future<Connection?> getConnectionBetween(String myId, String otherId);
  Future<void> sendRequest(String receiverId);
  Future<void> respondToRequest(String connectionId, {required bool accept});
  Future<void> cancelRequest(String connectionId);
  Future<void> removeConnection(String connectionId);
  Future<void> blockUser(String blockedId);
  Future<void> unblockUser(String blockedId);

  /// Whether the caller has blocked [otherId] — drives the Block/Unblock
  /// toggle wherever a profile's actions are shown.
  Future<bool> isBlockedByMe(String otherId);

  /// Every profile the caller has blocked.
  Future<List<BlockedUser>> getBlockedUsers();

  /// Sets (or replaces) the caller's own private pet name for [connectionId].
  Future<void> setPetName(String connectionId, String nickname);

  /// Removes the caller's pet name for [connectionId], if any.
  Future<void> removePetName(String connectionId);

  /// Every pet name the caller has set, keyed by the *other* profile's id
  /// rather than by connection id — the shape every name-rendering screen
  /// in the app actually needs (they have a profile id on hand, rarely a
  /// connection id). Backed entirely by `connection_nicknames`' RLS
  /// (`owner_id = auth.uid()`), so this can never return anyone else's.
  Future<Map<String, String>> getMyPetNames(String myId);
}
