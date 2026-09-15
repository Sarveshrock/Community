import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'failures.dart';

/// Translates raw exceptions from Supabase / Dart IO into the app's
/// [Failure] hierarchy so every repository speaks the same language.
Failure mapExceptionToFailure(Object error) {
  if (error is Failure) return error;

  if (error is SocketException || error is HttpException || error is TimeoutException) {
    return const NetworkFailure();
  }

  if (error is AuthException) {
    if (error.statusCode == '400' || error.statusCode == '401') {
      return AuthenticationFailure(error.message);
    }
    return ServerFailure(error.message);
  }

  if (error is PostgrestException) {
    final code = error.code;
    if (code == '42501') return const PermissionFailure();
    if (code == 'PGRST116') return const NotFoundFailure();
    if (code != null && code.startsWith('23')) {
      // integrity constraint violation (unique, check, fk, etc.)
      return ValidationFailure(error.message);
    }
    if (error.code == '429') return const RateLimitFailure();
    return ServerFailure(error.message);
  }

  if (error is StorageException) {
    return ServerFailure(error.message);
  }

  return UnknownFailure(error.toString());
}
