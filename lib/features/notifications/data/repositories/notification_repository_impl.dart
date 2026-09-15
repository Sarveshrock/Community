import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<AppNotification>> watchNotifications(String profileId) {
    return _client
        .from(Tables.notifications)
        .stream(primaryKey: ['id'])
        .eq('profile_id', profileId)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows.map(AppNotification.fromJson).toList());
  }

  @override
  Future<void> markRead(String notificationId) async {
    try {
      await _client
          .from(Tables.notifications)
          .update({'read_at': DateTime.now().toIso8601String()}).eq(
              'id', notificationId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Map<String, dynamic>?> getPreferences(String profileId) async {
    try {
      return await _client
          .from(Tables.notificationPreferences)
          .select()
          .eq('profile_id', profileId)
          .maybeSingle();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> updatePreferences(
      String profileId, Map<String, dynamic> changes) async {
    try {
      await _client
          .from(Tables.notificationPreferences)
          .upsert({'profile_id': profileId, ...changes});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> registerDeviceToken(
      String profileId, String token, String platform) async {
    try {
      await _client.from(Tables.deviceTokens).upsert(
        {'profile_id': profileId, 'token': token, 'platform': platform},
        onConflict: 'profile_id,token',
      );
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    try {
      await _client.from(Tables.deviceTokens).delete().eq('token', token);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
