import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => NotificationRepositoryImpl(supabase));

/// Realtime — updates live as invitations/join-requests/responses/messages
/// generate new notifications, no manual refresh needed (spec section 7).
final myNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watchNotifications(user.id);
});

final notificationPreferencesProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(notificationRepositoryProvider).getPreferences(user.id);
});

class NotificationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> markRead(String notificationId) async {
    // No manual refresh needed — the realtime stream reflects the update
    // (read_at change) as soon as Postgres commits it.
    final result = await AsyncValue.guard(() =>
        ref.read(notificationRepositoryProvider).markRead(notificationId));
    state = result;
  }

  Future<bool> updatePreferences(Map<String, dynamic> changes) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(notificationRepositoryProvider)
          .updatePreferences(user.id, changes),
    );
    state = result;
    if (!result.hasError) ref.invalidate(notificationPreferencesProvider);
    return !result.hasError;
  }

  Future<void> registerDeviceToken(String token, String platform) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await AsyncValue.guard(
      () => ref
          .read(notificationRepositoryProvider)
          .registerDeviceToken(user.id, token, platform),
    );
  }

  Future<void> unregisterDeviceToken(String token) async {
    await AsyncValue.guard(() =>
        ref.read(notificationRepositoryProvider).unregisterDeviceToken(token));
  }
}

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, void>(
        NotificationController.new);
