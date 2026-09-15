// Renders the Event Builder at every phone size the redesign brief calls
// out. This form is the single biggest overflow risk in the whole feature
// (several Row-based date/time pickers placed side by side) — this is
// exactly the kind of layout that silently clips on a narrow phone.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/events/presentation/screens/create_event_screen.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';

Widget _harness() {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const CreateEventScreen()),
    GoRoute(path: '/hackathons', builder: (_, __) => const Scaffold()),
  ]);
  return ProviderScope(
    overrides: [
      allSkillsProvider.overrideWith((ref) async => const [
            Skill(id: 's1', name: 'AI'),
            Skill(id: 's2', name: 'Web Development'),
            Skill(id: 's3', name: 'Cybersecurity'),
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
    testWidgets('Create Event lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Create Event'), findsOneWidget);
      expect(find.text('Basics'), findsOneWidget);
      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Advanced settings'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Speakers & Hosts'), findsOneWidget);
    });
  }

  testWidgets('switching mode to offline swaps online fields for venue fields', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.widgetWithText(TextFormField, 'Meeting URL'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Venue name'), findsNothing);

    final modeDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'Online');
    await tester.ensureVisible(modeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(modeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offline').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Meeting URL'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Venue name'), findsOneWidget);
  });

  testWidgets('picking Workshop reveals skill level and required software fields', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Expand "Advanced settings" so the workshop-only fields, if shown,
    // would actually be built.
    final advancedSettings = find.text('Advanced settings');
    await tester.ensureVisible(advancedSettings);
    await tester.pumpAndSettle();
    await tester.tap(advancedSettings);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Required software'), findsNothing);

    final categoryDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'Community Event');
    await tester.ensureVisible(categoryDropdown);
    await tester.pumpAndSettle();
    await tester.tap(categoryDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workshop').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Required software'), findsOneWidget);
  });
}
