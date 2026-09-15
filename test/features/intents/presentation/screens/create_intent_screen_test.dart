// Renders the redesigned single-page, mobile-first Create Intent screen at
// every phone size this session's redesign tests use, plus a check that
// switching the Intent Type (via the one dropdown, not separate cards) swaps
// the dynamic section without leaving a 1/9-style step indicator anywhere.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/intents/presentation/screens/create_intent_screen.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';

Widget _harness() {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const CreateIntentScreen()),
  ]);
  return ProviderScope(
    overrides: [
      allSkillsProvider.overrideWith((ref) async => const [
            Skill(id: 's1', name: 'Python'),
            Skill(id: 's2', name: 'React'),
            Skill(id: 's3', name: 'Node.js'),
            Skill(id: 's4', name: 'PostgreSQL'),
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
    testWidgets('Create Intent lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Create Intent'), findsOneWidget);
      expect(find.text('Intent type'), findsOneWidget);
      expect(find.text('Basic information'), findsOneWidget);
      expect(find.text('Skills'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Visibility & expiry'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Post Intent'), findsOneWidget);
      // The redesign's core requirement: one dropdown-style field, never a
      // 1/9-style step indicator or one box per Intent type.
      expect(find.textContaining('/9'), findsNothing);
    });
  }

  testWidgets('the Intent type field is a single control, not a card per type', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Only the currently-selected type's label appears on the page (as the
    // closed field's value) — every other type's label is not rendered
    // until the menu is opened.
    expect(find.text('Find Collaborator'), findsOneWidget);
    expect(find.text('Find a Job'), findsNothing);
    expect(find.text('Find a Mentor'), findsNothing);
  });

  testWidgets('opening the Intent type menu shows the 9 canonical options with an icon and description', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Find Collaborator').first);
    await tester.pumpAndSettle();

    expect(find.text('Find a Job'), findsOneWidget);
    expect(find.text('Discover career opportunities'), findsOneWidget);
    expect(find.text('Find a Mentor'), findsOneWidget);
    expect(find.text('Get guidance and advice'), findsOneWidget);
    expect(find.text('Offer Mentorship'), findsOneWidget);
    expect(find.text('Find Hackathon Team'), findsOneWidget);
    expect(find.text('Find Co-founder'), findsOneWidget);
    expect(find.text('Networking'), findsOneWidget);
    expect(find.text('Find Project'), findsOneWidget);
    expect(find.text('Learn / Study Together'), findsOneWidget);
    // Only the curated 9, not every IntentType (e.g. the finer-grained
    // "Find Developer" variant is not one of the picker's options).
    expect(find.text('Find Developer'), findsNothing);
  });

  testWidgets('selecting a different Intent type swaps the dynamic section', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Collaboration details'), findsOneWidget);

    await tester.tap(find.text('Find Collaborator').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find a Job'));
    await tester.pumpAndSettle();

    expect(find.text('Job search details'), findsOneWidget);
    expect(find.text('Collaboration details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing a title updates the live preview without a separate Preview button', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Fill in the form above to see a live preview.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'AI Powered Study Platform');
    await tester.pump();

    expect(find.text('AI Powered Study Platform'), findsWidgets);
    expect(find.text('Fill in the form above to see a live preview.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
