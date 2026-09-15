/// Centralized failure hierarchy (spec section 71). Repositories return or
/// throw these instead of leaking raw exceptions/PostgrestExceptions into
/// the presentation layer.
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure(
      [super.message = 'No internet connection. Please try again.']);
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure(
      [super.message = 'You need to sign in to continue.']);
}

class PermissionFailure extends Failure {
  const PermissionFailure(
      [super.message = 'You do not have permission to do that.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(
      [super.message = 'Please check the information you entered.']);
}

class ServerFailure extends Failure {
  const ServerFailure(
      [super.message = 'Something went wrong on our end. Please try again.']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(
      [super.message = 'We couldn\'t find what you were looking for.']);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure(
      [super.message = 'You\'re doing that too often. Please slow down.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'An unexpected error occurred.']);
}
