import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<void> signUpWithEmail(
      {required String email, required String password});

  Future<void> signInWithEmail(
      {required String email, required String password});

  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}
