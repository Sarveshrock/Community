// Renders Settings > Privacy > Profile Photo at every phone size this
// session's redesigns test at, and locks down that selecting an option
// actually calls through to the existing generic profile-update path
// (no parallel settings system for this one preference).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/auth/domain/entities/app_user.dart';
import 'package:community_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:community_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:community_app/features/settings/presentation/screens/profile_photo_privacy_screen.dart';

class _RecordingProfileRepository implements ProfileRepository {
  final List<Map<String, dynamic>> updateCalls = [];
  Profile profile = const Profile(id: 'user-1');

  @override
  Future<Profile> getProfile(String profileId) async => profile;

  @override
  Future<void> updateProfile(String profileId, Map<String, dynamic> changes) async {
    updateCalls.add(changes);
    profile = profile.copyWith();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(_RecordingProfileRepository repo, {Profile? profile}) {
  if (profile != null) repo.profile = profile;
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const ProfilePhotoPrivacyScreen()),
  ]);
  return ProviderScope(
    overrides: [
      // Deliberately not overriding myProfileProvider directly: letting its
      // real body run (watching authStateProvider, reading through
      // profileRepositoryProvider) is what warms authStateProvider before
      // any interaction — the same as it would be warmed in the real app by
      // the auth gate a user has already passed through to reach Settings.
      authStateProvider
          .overrideWith((ref) => Stream.value(const AppUser(id: 'user-1', email: 'a@example.com'))),
      profileRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  const phoneSizes = <String, Size>{
    'very small phone (320x568)': Size(320, 568),
    'small Android (360x800)': Size(360, 800),
    'iPhone SE-ish (375x812)': Size(375, 812),
    'iPhone 12/13 (390x844)': Size(390, 844),
    'large phone (414x896)': Size(414, 896),
    'large phone (430x932)': Size(430, 932),
  };

  for (final entry in phoneSizes.entries) {
    testWidgets('Profile Photo privacy screen lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(_RecordingProfileRepository()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('Connections Only'), findsOneWidget);
      expect(find.text('Only Me'), findsOneWidget);
    });
  }

  testWidgets('the current setting shows as selected', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _RecordingProfileRepository();
    await tester.pumpWidget(_harness(
      repo,
      profile: const Profile(id: 'user-1', photoVisibility: ProfilePhotoVisibility.connections),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final checkedRadios = tester.widgetList<Icon>(find.byIcon(Icons.radio_button_checked_rounded));
    expect(checkedRadios, hasLength(1));
  });

  testWidgets('selecting an option writes photo_visibility via the existing update path', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _RecordingProfileRepository();
    await tester.pumpWidget(_harness(repo, profile: const Profile(id: 'user-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Only Me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.updateCalls, hasLength(1));
    expect(repo.updateCalls.single, {'photo_visibility': 'only_me'});
  });
}
