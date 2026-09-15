import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final SupabaseClient _client;

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email,
      emailConfirmed: user.emailConfirmedAt != null,
    );
  }

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() {
    return _client.auth.onAuthStateChange
        .map((state) => _mapUser(state.session?.user));
  }

  @override
  Future<void> signUpWithEmail(
      {required String email, required String password}) async {
    try {
      await _client.auth.signUp(email: email, password: password);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> signInWithEmail(
      {required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> signInWithApple() async {
    try {
      await _client.auth.signInWithOAuth(OAuthProvider.apple);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
