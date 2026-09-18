import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_config.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(supabase);
});

/// Live authentication state, driving the router redirect (Splash -> Auth ->
/// Home per spec section 52).
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});

/// Drives loading/error UI for sign-in/sign-up forms. Kept separate from
/// [authStateProvider] so a failed sign-in attempt doesn't disturb the
/// app-wide auth stream.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password),
    );
    state = result;
    return !result.hasError;
  }

  Future<bool> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signUpWithEmail(email: email, password: password),
    );
    state = result;
    return !result.hasError;
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).signInWithGoogle());
    state = result;
    return !result.hasError;
  }

  Future<bool> signInWithApple() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).signInWithApple());
    state = result;
    return !result.hasError;
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).sendPasswordResetEmail(email));
    state = result;
    return !result.hasError;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    // Unregister this device's push token *before* the session ends —
    // `device_tokens`'s RLS delete policy needs `auth.uid()` to still
    // resolve, which it won't once signed out. Best-effort: a failure here
    // (e.g. push was never set up) must never block sign-out itself.
    final token = await PushNotificationService.currentToken();
    if (token != null) {
      await AsyncValue.guard(() => ref
          .read(notificationControllerProvider.notifier)
          .unregisterDeviceToken(token));
    }
    state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).signOut());
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
