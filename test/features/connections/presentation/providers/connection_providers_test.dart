// Locks down formatConnectionDisplayName — the centralized rule behind
// getDisplayName() that every name-rendering screen in the app is supposed
// to funnel through. The one thing this must never do is show "Name ()".

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/connections/presentation/providers/connection_providers.dart';

void main() {
  test('no pet name falls back to just the main name', () {
    expect(
      formatConnectionDisplayName(mainName: 'Shivam', petName: null),
      'Shivam',
    );
  });

  test('an empty-string pet name is treated the same as no pet name', () {
    expect(
      formatConnectionDisplayName(mainName: 'Shivam', petName: ''),
      'Shivam',
    );
  });

  test('a set pet name is appended in parentheses', () {
    expect(
      formatConnectionDisplayName(mainName: 'Shivam', petName: 'Shivu'),
      'Shivam (Shivu)',
    );
  });

  test('never renders empty parentheses', () {
    final result =
        formatConnectionDisplayName(mainName: 'Shivam', petName: null);
    expect(result.contains('()'), isFalse);
  });

  test(
      'a missing/empty main name falls back to a generic label, pet name still applied',
      () {
    expect(
      formatConnectionDisplayName(mainName: null, petName: 'Bro'),
      'Community member (Bro)',
    );
    expect(
      formatConnectionDisplayName(mainName: '', petName: null),
      'Community member',
    );
  });
}
