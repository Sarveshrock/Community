// Renders the Community Builder at every phone size the redesign brief
// calls out, mirroring create_job_screen_test's precedent for this kind of
// sectioned builder form.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/communities/presentation/screens/create_community_screen.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';

Widget _harness() {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const CreateCommunityScreen()),
  ]);
  return ProviderScope(
    overrides: [
      allSkillsProvider.overrideWith((ref) async => const [
            Skill(id: 's1', name: 'Java'),
            Skill(id: 's2', name: 'Spring Boot'),
          ]),
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
    testWidgets('New Community lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('New Community'), findsOneWidget);
      expect(find.text('Basic information'), findsOneWidget);
      expect(find.text('Topics & tags'), findsOneWidget);
      expect(find.text('What can members do here?'), findsOneWidget);
      expect(find.text('Who is this community for?'), findsOneWidget);
      expect(find.text('Community rules'), findsOneWidget);
      expect(find.text('Privacy & access'), findsOneWidget);
    });
  }

  testWidgets('defaults to Public and explains what that means', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Anyone can discover and join instantly.'), findsOneWidget);

    final accessDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'Public');
    await tester.ensureVisible(accessDropdown);
    await tester.pumpAndSettle();
    await tester.tap(accessDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request to join').last);
    await tester.pumpAndSettle();

    expect(find.text('Anyone can discover this community, but joining requires your approval.'), findsOneWidget);
  });

  testWidgets('reaches the Preview step with a name entered', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.widgetWithText(TextFormField, 'Community name'), 'Java Developers India');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final previewButton = find.text('Preview').first;
    await tester.ensureVisible(previewButton);
    await tester.pumpAndSettle();
    await tester.tap(previewButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Java Developers India'), findsOneWidget);
    expect(find.text('Create Community'), findsOneWidget);
    expect(find.text('Back to edit'), findsOneWidget);
  });
}
