import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/settings/domain/app_icon_style.dart';

void main() {
  test('every style has a unique key', () {
    final keys = kAppIconStyles.map((s) => s.key).toList();
    expect(keys.toSet().length, keys.length);
  });

  test('exactly one style is unsupported: custom, and it says why', () {
    final unsupported = kAppIconStyles.where((s) => !s.supported).toList();
    expect(unsupported, hasLength(1));
    expect(unsupported.single.key, 'custom');
    expect(unsupported.single.description, isNotEmpty);
  });

  test('every predefined (non-custom) style is marked supported', () {
    for (final style in kAppIconStyles.where((s) => s.key != 'custom')) {
      expect(style.supported, isTrue, reason: '${style.key} should be a real, applicable style');
    }
  });

  test('appIconStyleFromKey resolves a known key', () {
    expect(appIconStyleFromKey('neon').label, 'Neon');
  });

  test('appIconStyleFromKey falls back to the first style (classic) for an unknown key', () {
    expect(appIconStyleFromKey('not-a-real-style').key, 'classic');
    expect(appIconStyleFromKey(null).key, 'classic');
  });

  test('previewAsset points at the per-style bundled preview image', () {
    expect(appIconStyleFromKey('dark').previewAsset, 'assets/app_icons/dark.png');
  });
}
