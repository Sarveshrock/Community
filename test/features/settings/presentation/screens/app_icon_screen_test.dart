// Renders Settings > Appearance > App Icon at every phone size this
// session's redesigns test at. Locks down the platform-limitation handling
// for "Custom" (shown, disabled, never fakes a change) and that selecting a
// real style then tapping Apply calls through to the existing generic
// profile-update path.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/auth/domain/entities/app_user.dart';
import 'package:community_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:community_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:community_app/features/settings/presentation/screens/app_icon_screen.dart';

class _RecordingProfileRepository implements ProfileRepository {
  final List<Map<String, dynamic>> updateCalls = [];
  Profile profile = const Profile(id: 'user-1');

  @override
  Future<Profile> getProfile(String profileId) async => profile;

  @override
  Future<void> updateProfile(String profileId, Map<String, dynamic> changes) async {
    updateCalls.add(changes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(_RecordingProfileRepository repo) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const AppIconScreen()),
  ]);
  return ProviderScope(
    overrides: [
      authStateProvider
          .overrideWith((ref) => Stream.value(const AppUser(id: 'user-1', email: 'a@example.com'))),
      profileRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  // The real native handlers only exist in the compiled Android/iOS apps
  // (MainActivity.kt / AppDelegate.swift) — mock this channel explicitly
  // rather than relying on however the test binding happens to treat an
  // unmocked channel, so `AppIconService.setIcon`'s await actually
  // resolves instead of hanging indefinitely.
  const channel = MethodChannel('com.communeo.app/app_icon');
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const phoneSizes = <String, Size>{
    'very small phone (320x568)': Size(320, 568),
    'small Android (360x800)': Size(360, 800),
    'iPhone SE-ish (375x812)': Size(375, 812),
    'iPhone 12/13 (390x844)': Size(390, 844),
    'large phone (414x896)': Size(414, 896),
    'large phone (430x932)': Size(430, 932),
  };

  for (final entry in phoneSizes.entries) {
    testWidgets('App Icon screen lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(_RecordingProfileRepository()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Customize your Communeo icon'), findsOneWidget);
      // "Classic" appears twice by default: the grid tile and the live
      // Preview section (Classic is the default selected style).
      expect(find.text('Classic'), findsWidgets);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Apply Icon'), findsOneWidget);
    });
  }

  testWidgets('Custom is shown but locked, and tapping it never selects it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_RecordingProfileRepository()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

    await tester.tap(find.text('Custom'));
    await tester.pump();

    // Still Classic selected (the lock icon for Custom is still present,
    // i.e. tapping it didn't turn it into the checked/selected state).
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('selecting a style and applying calls through to the existing update path', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _RecordingProfileRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Neon'));
    await tester.pump();

    final applyButton = find.widgetWithText(FilledButton, 'Apply Icon');
    expect(tester.widget<FilledButton>(applyButton).onPressed, isNotNull);

    await tester.tap(applyButton);
    // Not pumpAndSettle: the button shows an indeterminate
    // CircularProgressIndicator while saving, which animates forever and
    // would make pumpAndSettle time out regardless of whether the
    // underlying async work (a mocked MethodChannel round-trip, then the
    // repository call) has actually finished.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(repo.updateCalls, hasLength(1));
    expect(repo.updateCalls.single, {'app_icon_style': 'neon'});
  });

  testWidgets('Apply is disabled until a different style is actually selected', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_RecordingProfileRepository()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final applyButton = find.widgetWithText(FilledButton, 'Apply Icon');
    expect(tester.widget<FilledButton>(applyButton).onPressed, isNull);
  });
}
