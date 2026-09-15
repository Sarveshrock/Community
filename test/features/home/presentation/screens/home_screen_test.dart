// Renders the redesigned Home screen at real phone sizes with every
// Supabase-backed provider stubbed out. The point isn't the assertions on
// text so much as `tester.takeException()` — a RenderFlex overflow (the
// classic "desktop layout squeezed into a phone" failure) surfaces there,
// so this catches it on the narrowest supported screen instead of on a
// device.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/core/theme/app_theme.dart';
import 'package:community_app/features/home/presentation/providers/home_providers.dart';
import 'package:community_app/features/home/presentation/screens/home_screen.dart';
import 'package:community_app/features/intents/presentation/providers/intent_providers.dart';
import 'package:community_app/features/posts/domain/entities/post.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';

final _hackathons = [
  {'id': 'h1', 'name': 'Mock DevSprint 2030', 'event_date': '2026-09-10'},
  {'id': 'h2', 'name': 'Mock InnovateX 2029', 'event_date': '2026-09-09'},
];
final _jobs = [
  {
    'id': 'j1',
    'title': 'Mock Frontend Engineer #2',
    'company_name': 'Vivaan Wong\'s Company',
  },
];
final _projects = [
  {'id': 'p1', 'title': 'Mock Project #8', 'category': 'Web App'},
];

Widget _harness() {
  return ProviderScope(
    overrides: [
      myProfileProvider.overrideWith(
          (ref) async => const Profile(id: 'u1', fullName: 'Shivam Sharma')),
      myIntentsProvider.overrideWith((ref) async => const <UserIntent>[]),
      pendingConnectionRequestsCountProvider.overrideWith((ref) async => 2),
      unreadNotificationsCountProvider.overrideWithValue(3),
      homeHackathonsPreviewProvider.overrideWith((ref) async => _hackathons),
      homeJobsPreviewProvider.overrideWith((ref) async => _jobs),
      homeProjectsPreviewProvider.overrideWith((ref) async => _projects),
      // Empty on purpose: PostCard pulls in its own auth/like providers,
      // which this layout test has no reason to stand up.
      homePostsPreviewProvider.overrideWith((ref) async => const <Post>[]),
      communityStatsProvider.overrideWith((ref) async =>
          (people: 1200, projects: 340, opportunities: 89, communities: 12)),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: const HomeScreen()),
  );
}

/// Two pumps rather than pumpAndSettle: the shimmer skeletons animate
/// forever by design, so settling would never complete.
Future<void> _pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(_harness());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  const phoneSizes = <String, Size>{
    'very small phone (320x640)': Size(320, 640),
    'small Android (360x800)': Size(360, 800),
    'iPhone SE-ish (375x812)': Size(375, 812),
    'large phone (430x932)': Size(430, 932),
  };

  for (final entry in phoneSizes.entries) {
    testWidgets('Home lays out with no overflow on ${entry.key}',
        (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpHome(tester);

      expect(tester.takeException(), isNull);
      // The name is a separate gradient-masked Text, so the greeting is two
      // widgets rather than one string.
      expect(find.text('Hi '), findsOneWidget);
      expect(find.text('Shivam,'), findsOneWidget);
      expect(find.text('What are you looking to accomplish?'), findsOneWidget);
    });
  }

  testWidgets('Home shows the greeting, intent CTA and quick actions',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(tester);

    expect(find.text('Hi '), findsOneWidget);
    expect(find.text('Shivam,'), findsOneWidget);
    expect(find.text('What do you want to do today?'), findsOneWidget);
    expect(
      find.text('Declare an intent and let Communeo find the right people'),
      findsOneWidget,
    );
    // Quick actions keep the exact existing product terminology.
    expect(find.text('Buddies'), findsOneWidget);
    expect(find.text('Find a Person'), findsOneWidget);
    expect(find.text('Find a Team'), findsOneWidget);
  });

  testWidgets('Home renders section carousels from their providers',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(tester);

    // Scroll to the content sections, which now sit below the action grid,
    // inspiration card and stats row.
    await tester.scrollUntilVisible(
      find.text('Mock DevSprint 2030'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Hackathons'), findsOneWidget);
    expect(find.text('Mock DevSprint 2030'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending connection requests surface as a tappable card',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(tester);

    expect(find.text('2 pending connection requests'), findsOneWidget);
  });
}
