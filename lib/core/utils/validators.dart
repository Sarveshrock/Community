/// Client-side validation only. The database enforces the same rules at the
/// constraint level (spec section 83) — these exist purely for fast UX
/// feedback, never as the source of truth.
class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w\.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    final regex = RegExp(r'^[a-z0-9_]{3,30}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Use 3-30 lowercase letters, numbers, or underscores';
    }
    return null;
  }

  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional field
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.isAbsolute) return 'Enter a valid URL';
    return null;
  }
}
