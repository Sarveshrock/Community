import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/connection.dart';
import '../../domain/repositories/connection_repository.dart';

class ConnectionRepositoryImpl implements ConnectionRepository {
  ConnectionRepositoryImpl(this._client);

  final SupabaseClient _client;

  // city/country/profile_interests/bio/updated_at are additive over the
  // original select — real profile data the Buddies card redesign
  // surfaces (location, tags, bio, an online-status proxy) that nothing
  // previously requested here. profile_interests comes back empty rather
  // than erroring when profile_interests_select RLS hides it (the other
  // party isn't professional_discoverable) — same graceful degradation the
  // rest of the app already relies on for optional embeds.
  static const _profileFields =
      'full_name, avatar_url, current_role, city, country, bio, updated_at, profile_interests(interests(name))';
  static const _select =
      '*, requester_profile:profiles!connections_requester_id_fkey($_profileFields), '
      'receiver_profile:profiles!connections_receiver_id_fkey($_profileFields), '
      // RLS on connection_nicknames restricts this embed to the caller's own
      // nickname row for the connection — never the other party's.
      'connection_nicknames(nickname)';

  @override
  Future<List<Connection>> getMyConnections(String myId,
      {ConnectionStatus? status}) async {
    try {
      var query = _client
          .from(Tables.connections)
          .select(_select)
          .or('requester_id.eq.$myId,receiver_id.eq.$myId');
      if (status != null) query = query.eq('status', status.value);
      final data = await query.order('created_at', ascending: false);
      return (data as List)
          .map((e) =>
              Connection.fromJson(e as Map<String, dynamic>, viewerId: myId))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Connection?> getConnectionBetween(String myId, String otherId) async {
    try {
      final data = await _client
          .from(Tables.connections)
          .select(_select)
          .or('and(requester_id.eq.$myId,receiver_id.eq.$otherId),and(requester_id.eq.$otherId,receiver_id.eq.$myId)')
          .maybeSingle();
      if (data == null) return null;
      return Connection.fromJson(data, viewerId: myId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> sendRequest(String receiverId) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.connections).insert({
        'requester_id': myId,
        'receiver_id': receiverId,
        'status': 'pending',
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> respondToRequest(String connectionId,
      {required bool accept}) async {
    try {
      await _client.from(Tables.connections).update(
          {'status': accept ? 'accepted' : 'declined'}).eq('id', connectionId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> cancelRequest(String connectionId) async {
    try {
      await _client
          .from(Tables.connections)
          .update({'status': 'cancelled'}).eq('id', connectionId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> removeConnection(String connectionId) async {
    try {
      await _client.from(Tables.connections).delete().eq('id', connectionId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> blockUser(String blockedId) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client
          .from(Tables.blocks)
          .insert({'blocker_id': myId, 'blocked_id': blockedId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> unblockUser(String blockedId) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client
          .from(Tables.blocks)
          .delete()
          .eq('blocker_id', myId)
          .eq('blocked_id', blockedId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<bool> isBlockedByMe(String otherId) async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return false;
      final data = await _client
          .from(Tables.blocks)
          .select('id')
          .eq('blocker_id', myId)
          .eq('blocked_id', otherId)
          .maybeSingle();
      return data != null;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<BlockedUser>> getBlockedUsers() async {
    try {
      final myId = _client.auth.currentUser!.id;
      final data = await _client
          .from(Tables.blocks)
          .select(
              'blocked_id, profiles!blocks_blocked_id_fkey(full_name, avatar_url, current_role)')
          .eq('blocker_id', myId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> setPetName(String connectionId, String nickname) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.connectionNicknames).upsert(
        {
          'connection_id': connectionId,
          'owner_id': myId,
          'nickname': nickname.trim(),
        },
        onConflict: 'connection_id,owner_id',
      );
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> removePetName(String connectionId) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client
          .from(Tables.connectionNicknames)
          .delete()
          .eq('connection_id', connectionId)
          .eq('owner_id', myId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Map<String, String>> getMyPetNames(String myId) async {
    try {
      final data = await _client
          .from(Tables.connectionNicknames)
          .select('nickname, connections(requester_id, receiver_id)')
          .eq('owner_id', myId);
      final result = <String, String>{};
      for (final row in (data as List)) {
        final map = row as Map<String, dynamic>;
        final conn = map['connections'] as Map<String, dynamic>?;
        if (conn == null) continue;
        final requesterId = conn['requester_id'] as String;
        final receiverId = conn['receiver_id'] as String;
        final otherId = requesterId == myId ? receiverId : requesterId;
        result[otherId] = map['nickname'] as String;
      }
      return result;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
