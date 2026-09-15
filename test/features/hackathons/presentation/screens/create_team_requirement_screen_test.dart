// Renders the Team Builder at every phone size the redesign brief calls
// out. This form has several Row-based paired fields (min/max team size,
// role priority/skills) — exactly the kind of layout that silently clips
// on a narrow phone, mirroring create_job_screen_test's precedent.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/hackathons/presentation/screens/create_team_requirement_screen.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';

Widget _harness({String? hackathonId, String? hackathonName}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => CreateTeamRequirementScreen(hackathonId: hackathonId, hackathonName: hackathonName),
    ),
  ]);
  return ProviderScope(
    overrides: [
      allSkillsProvider.overrideWith((ref) async => const [
            Skill(id: 's1', name: 'Python'),
            Skill(id: 's2', name: 'React'),
            Skill(id: 's3', name: 'FastAPI'),
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
    testWidgets('Post a Team lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(hackathonId: 'hack-1', hackathonName: 'AI Hackathon 2026'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Post a Team'), findsOneWidget);
      expect(find.text('Team basics'), findsOneWidget);
      expect(find.text('Project'), findsOneWidget);
      expect(find.text('Looking for'), findsOneWidget);
      expect(find.text('Skills'), findsOneWidget);
      expect(find.text('Team size'), findsOneWidget);
      expect(find.text('Collaboration'), findsOneWidget);
    });
  }

  testWidgets('without a pre-picked hackathon, shows the hackathon name field', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Hackathon'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Hackathon name'), findsOneWidget);
  });

  testWidgets('choosing In-person collaboration reveals the location field', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(hackathonId: 'hack-1', hackathonName: 'AI Hackathon 2026'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.widgetWithText(TextFormField, 'Location'), findsNothing);

    final modeDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'Online');
    await tester.ensureVisible(modeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(modeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('In-person').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Location'), findsOneWidget);
  });

  testWidgets('requires a tagline or project description before previewing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(hackathonId: 'hack-1', hackathonName: 'AI Hackathon 2026'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.widgetWithText(TextFormField, 'Team name'), 'Team Nova');

    final previewButton = find.text('Preview').first;
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pump();

    // Still on the form — validation blocked the preview.
    expect(find.text('Team basics'), findsOneWidget);
  });

  testWidgets('filling required fields reaches the Preview step with the entered data', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(hackathonId: 'hack-1', hackathonName: 'AI Hackathon 2026'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.widgetWithText(TextFormField, 'Team name'), 'Team Nova');
    await tester.enterText(find.widgetWithText(TextFormField, 'Team tagline (optional)'), 'AI copilots for hackathons');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final previewButton = find.text('Preview').first;
    await tester.ensureVisible(previewButton);
    await tester.pumpAndSettle();
    await tester.tap(previewButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Team Nova'), findsOneWidget);
    expect(find.text('AI copilots for hackathons'), findsOneWidget);
    expect(find.text('Post team'), findsOneWidget);
    expect(find.text('Back to edit'), findsOneWidget);
  });
}
