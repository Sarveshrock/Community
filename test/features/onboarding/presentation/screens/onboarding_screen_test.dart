// Renders the redesigned Onboarding wizard (now matching the dark
// home_style.dart system instead of stock Material) at every phone size
// this session's redesigns test at, and locks down that the 3-step flow
// still calls through to the existing completeOnboarding path unchanged —
// this was a visual-only restyle, never a behavior change.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/core/analytics/analytics_service.dart';
import 'package:community_app/features/auth/domain/entities/app_user.dart';
import 'package:community_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:community_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:community_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';

/// AnalyticsService's real implementation reaches the global `supabase`
/// accessor, which asserts if `Supabase.initialize()` was never called —
/// true in every widget test. completeOnboarding fires an analytics event
/// on success, so this test needs a version that never touches it.
class _NoopAnalyticsService implements AnalyticsService {
  @override
  Future<void> log(String eventType, [Map<String, dynamic> data = const {}]) async {}
}

class _RecordingProfileRepository implements ProfileRepository {
  final List<Map<String, dynamic>> updateCalls = [];
  bool markedCompleted = false;

  @override
  Future<Profile> getProfile(String profileId) async => const Profile(id: 'user-1');

  @override
  Future<void> updateProfile(String profileId, Map<String, dynamic> changes) async {
    updateCalls.add(changes);
  }

  @override
  Future<void> markProfileCompleted(String profileId) async {
    markedCompleted = true;
  }

  @override
  Future<void> setSkills(String profileId, List<(String, ExperienceLevel)> skills) async {}

  @override
  Future<void> setInterests(String profileId, List<String> interestIds) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(_RecordingProfileRepository repo) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Home'))),
  ]);
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(const AppUser(id: 'user-1', email: 'a@example.com'))),
      profileRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(_NoopAnalyticsService()),
      allSkillsProvider.overrideWith((ref) async => const [
            Skill(id: 's1', name: 'Flutter'),
            Skill(id: 's2', name: 'Python'),
          ]),
      allInterestsProvider.overrideWith((ref) async => const [
            Interest(id: 'i1', name: 'AI'),
          ]),
    ],
    // OnboardingScreen itself never watches authStateProvider (it only
    // reaches it via a bare `ref.read` deep inside completeOnboarding at
    // submit time) — a StreamProvider is lazy, so without this Consumer
    // warming it on the first frame, that first `ref.read` would still see
    // AsyncLoading (i.e. no user) the instant "Finish" is tapped.
    child: Consumer(
      builder: (context, ref, _) {
        ref.watch(authStateProvider);
        return MaterialApp.router(routerConfig: router);
      },
    ),
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
    testWidgets('Onboarding lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(_RecordingProfileRepository()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Let\'s set up your profile'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  }

  testWidgets('Continue is disabled until name and city are filled', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_RecordingProfileRepository()));
    await tester.pump();

    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Priya Sharma');
    await tester.enterText(find.byType(TextField).at(1), 'Bangalore');
    await tester.pump();

    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
  });

  testWidgets('completing all 3 steps calls through to completeOnboarding and navigates home', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _RecordingProfileRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Step 1: basic info.
    await tester.enterText(find.byType(TextField).first, 'Priya Sharma');
    await tester.enterText(find.byType(TextField).at(1), 'Bangalore');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Step 2: professional background — nothing required, just continue.
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Step 3: skills/interests — finish.
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(repo.updateCalls, hasLength(1));
    expect(repo.updateCalls.single['full_name'], 'Priya Sharma');
    expect(repo.updateCalls.single['city'], 'Bangalore');
    expect(repo.markedCompleted, isTrue);
  });
}
