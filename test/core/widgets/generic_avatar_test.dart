// Locks down the generic-avatar sentinel scheme — the same `avatar_url`
// column real photos use, so every existing "render profile.avatarUrl" call
// site must keep working (and every one of them routes through UserAvatar,
// which interprets this sentinel) without any of them needing to change.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/core/widgets/generic_avatar.dart';

void main() {
  test('genericAvatarUrlFor round-trips through isGenericAvatarUrl/genericAvatarFromUrl', () {
    final url = genericAvatarUrlFor(3);
    expect(isGenericAvatarUrl(url), isTrue);
    expect(genericAvatarFromUrl(url), genericAvatarCatalog[3]);
  });

  test('a real https URL is never mistaken for a generic avatar', () {
    expect(isGenericAvatarUrl('https://example.com/a.png'), isFalse);
  });

  test('null and empty are not generic avatars', () {
    expect(isGenericAvatarUrl(null), isFalse);
    expect(isGenericAvatarUrl(''), isFalse);
  });

  test('an out-of-range or malformed index degrades to null, not a crash', () {
    expect(genericAvatarFromUrl(genericAvatarUrlFor(9999)), isNull);
    expect(genericAvatarFromUrl('generic-avatar://not-a-number'), isNull);
  });

  test('the catalog has no duplicate icon+color combinations', () {
    final seen = <String>{};
    for (final option in genericAvatarCatalog) {
      final key = '${option.icon.codePoint}-${option.colors.map((c) => c.toARGB32())}';
      expect(seen.add(key), isTrue, reason: 'Duplicate avatar option: $key');
    }
  });
}
