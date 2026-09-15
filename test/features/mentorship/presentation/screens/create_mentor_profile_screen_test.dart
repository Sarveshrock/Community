// Renders the Create/Edit Mentor Profile screen at every phone size the
// redesign brief calls out, and checks the Free/Paid conditional pricing
// fields and the Preview step, mirroring create_job_screen_test's
// precedent for this kind of sectioned builder form.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/auth/domain/entities/app_user.dart';
import 'package:community_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:community_app/features/mentorship/presentation/providers/mentor_providers.dart';
import 'package:community_app/features/mentorship/presentation/screens/create_mentor_profile_screen.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';

const _profile = Profile(
  id: 'user-1',
  fullName: 'Ada Lovelace',
  currentRole: 'Backend Engineer',
  currentCompany: 'Acme',
  totalItExperienceMonths: 48,
);

Widget _harness({Mentor? mentor}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const CreateMentorProfileScreen()),
  ]);
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
          (ref) => Stream.value(const AppUser(id: 'user-1', email: 'ada@example.com'))),
      myProfileProvider.overrideWith((ref) async => _profile),
      myExperiencesProvider.overrideWith((ref) async => const []),
      myEducationProvider.overrideWith((ref) async => const []),
      allSkillsProvider.overrideWith((ref) async => const [
            Skill(id: 's1', name: 'Java'),
            Skill(id: 's2', name: 'System Design'),
          ]),
      myMentorProfileProvider.overrideWith((ref) async => mentor),
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
    testWidgets('Become a Mentor lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Become a Mentor'), findsOneWidget);
      expect(find.text('What can you mentor?'), findsOneWidget);
      expect(find.text('What can you help with?'), findsOneWidget);
      expect(find.text('Mentor introduction'), findsOneWidget);
      expect(find.text('Your background'), findsOneWidget);
      expect(find.text('Mentorship format'), findsOneWidget);
      expect(find.text('Pricing'), findsOneWidget);
      expect(find.text('Availability'), findsOneWidget);
    });
  }

  testWidgets('shows "Edit Mentorship" and pre-fills fields when a mentor profile already exists',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mentor = Mentor(
      profileId: 'user-1',
      available: true,
      expertise: ['Java'],
      topics: ['Interview preparation'],
      headline: 'Helping backend engineers grow',
      bio: 'I love mentoring.',
      pricingType: 'paid',
      price: 500,
      currency: 'INR',
    );
    await tester.pumpWidget(_harness(mentor: mentor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Edit Mentorship'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mentorship headline'), findsOneWidget);
    expect(find.text('Helping backend engineers grow'), findsOneWidget);
    // Paid mentor pre-fills with the pricing fields already visible.
    expect(find.widgetWithText(TextFormField, 'Session price'), findsOneWidget);
  });

  testWidgets('defaults to Free and selecting Paid reveals price/currency fields', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.widgetWithText(TextFormField, 'Session price'), findsNothing);

    final paidOption = find.text('Paid');
    await tester.ensureVisible(paidOption);
    await tester.pumpAndSettle();
    await tester.tap(paidOption);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Session price'), findsOneWidget);
  });

  testWidgets('requires at least one expertise before previewing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Fill required text fields but leave expertise empty.
    await tester.enterText(find.widgetWithText(TextFormField, 'Mentorship headline'), 'A headline');
    await tester.enterText(find.widgetWithText(TextFormField, 'About your mentorship'), 'About text');

    final previewButton = find.text('Preview');
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pump();

    // Still on the form — validation blocked the preview.
    expect(find.text('What can you mentor?'), findsOneWidget);
  });

  testWidgets('filling everything reaches the Preview step with the entered data', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.widgetWithText(TextFormField, 'Mentorship headline'), 'Helping devs grow');
    await tester.enterText(find.widgetWithText(TextFormField, 'About your mentorship'), 'I mentor backend devs.');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final javaChip = find.text('Java');
    await tester.ensureVisible(javaChip);
    await tester.pumpAndSettle();
    await tester.tap(javaChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    final previewButton = find.text('Preview');
    await tester.ensureVisible(previewButton);
    await tester.pumpAndSettle();
    await tester.tap(previewButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Helping devs grow'), findsOneWidget);
    expect(find.text('I mentor backend devs.'), findsOneWidget);
    expect(find.text('Become a Mentor'), findsOneWidget);
    expect(find.text('Back to edit'), findsOneWidget);
  });
}
