import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('rejects empty', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email(null), isNotNull);
    });

    test('rejects malformed addresses', () {
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('missing@domain'), isNotNull);
    });

    test('accepts valid addresses', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('  user@example.com  '), isNull);
    });
  });

  group('Validators.password', () {
    test('rejects short passwords', () {
      expect(Validators.password('short'), isNotNull);
    });

    test('accepts 8+ characters', () {
      expect(Validators.password('longenough'), isNull);
    });
  });

  group('Validators.username', () {
    test('rejects uppercase, spaces, and short usernames', () {
      expect(Validators.username('AB'), isNotNull);
      expect(Validators.username('Has Space'), isNotNull);
      expect(Validators.username('UpperCase'), isNotNull);
    });

    test('accepts lowercase alphanumeric + underscore', () {
      expect(Validators.username('valid_user_123'), isNull);
    });
  });

  group('Validators.url', () {
    test('optional field allows empty', () {
      expect(Validators.url(''), isNull);
      expect(Validators.url(null), isNull);
    });

    test('rejects non-absolute URLs', () {
      expect(Validators.url('not a url'), isNotNull);
    });

    test('accepts absolute URLs', () {
      expect(Validators.url('https://github.com/someone'), isNull);
    });
  });

  group('Validators.required', () {
    test('flags empty/whitespace-only values', () {
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('   '), isNotNull);
    });

    test('accepts non-empty values', () {
      expect(Validators.required('value'), isNull);
    });
  });
}
