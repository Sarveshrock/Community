import '../entities/app_notification.dart';

abstract class NotificationRepository {
  /// Realtime — a new notification (invitation, join request, response,
  /// message, etc.) appears without the user needing to refresh (spec
  /// section 7), the same way messages already stream live.
  Stream<List<AppNotification>> watchNotifications(String profileId);

  Future<void> markRead(String notificationId);
  Future<Map<String, dynamic>?> getPreferences(String profileId);
  Future<void> updatePreferences(
      String profileId, Map<String, dynamic> changes);

  /// Registers this device's push token for [profileId] (spec section 47).
  Future<void> registerDeviceToken(
      String profileId, String token, String platform);

  /// Removes this device's push token, e.g. on sign-out.
  Future<void> unregisterDeviceToken(String token);
}
