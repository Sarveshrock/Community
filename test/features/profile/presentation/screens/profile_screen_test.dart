// Renders the redesigned Profile screen (own-profile view) at every phone
// size the redesign brief calls out, and locks down the "never invent a
// stat/field that doesn't exist" requirement: only Posts/Connections show
// in the stats row (no fake "Profile views"/"Saved" counts), and the
// header/settings navigation is unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/auth/domain/entities/app_user.dart';
import 'package:community_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:community_app/features/connections/presentation/providers/connection_providers.dart';
import 'package:community_app/features/mentorship/presentation/providers/mentor_providers.dart';
import 'package:community_app/features/posts/presentation/providers/post_providers.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:community_app/features/profile/presentation/screens/profile_screen.dart';

final _profile = Profile(
  id: 'user-1',
  fullName: 'Shivam Sharma-Krishnamurthy-Alexanderopoulos',
  currentRole: 'Senior Backend Systems Engineering Lead',
  currentCompany: 'A Very Long International Technology Corporation Pvt Ltd',
  city: 'Pune',
  country: 'Maharashtra',
  bio: 'Building scalable systems and exploring new technologies. Always open to connect and collaborate!',
  careerGoals: 'Opportunities to work on open source projects and connect with fellow developers.',
  totalItExperienceMonths: 30,
  updatedAt: DateTime.now(),
  skills: const [
    ProfileSkill(skill: Skill(id: 's1', name: 'UI/UX Design'), level: ExperienceLevel.advanced),
    ProfileSkill(skill: Skill(id: 's2', name: 'Product Management'), level: ExperienceLevel.advanced),
    ProfileSkill(skill: Skill(id: 's3', name: 'Swift'), level: ExperienceLevel.intermediate),
    ProfileSkill(skill: Skill(id: 's4', name: 'Machine Learning'), level: ExperienceLevel.beginner),
  ],
  interests: const [
    Interest(id: 'i1', name: 'Running'),
    Interest(id: 'i2', name: 'Open Source'),
    Interest(id: 'i3', name: 'Startups'),
    Interest(id: 'i4', name: 'Machine Learning'),
  ],
);

Widget _harness({Mentor? mentor}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/profile/edit', builder: (_, __) => const Scaffold()),
    GoRoute(path: '/settings', builder: (_, __) => const Scaffold()),
    GoRoute(path: '/posts/new', builder: (_, __) => const Scaffold()),
    GoRoute(path: '/mentors/me/manage', builder: (_, __) => const Scaffold()),
    GoRoute(path: '/mentors/:id', builder: (_, __) => const Scaffold()),
  ]);
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
          (ref) => Stream.value(const AppUser(id: 'user-1', email: 'shivam@example.com'))),
      myProfileProvider.overrideWith((ref) async => _profile),
      authorPostsProvider('user-1').overrideWith((ref) async => const []),
      buddiesProvider.overrideWith((ref) async => const []),
      myOptionalProofsProvider.overrideWith((ref) async => const []),
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
    testWidgets('Profile lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('My Profile'), findsOneWidget);
    });
  }

  testWidgets('shows only real, existing stats — no fabricated Profile views/Saved counts',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // "Posts" legitimately renders twice: the stat label and the Posts
    // section header below it.
    expect(find.text('Posts'), findsNWidgets(2));
    expect(find.text('Connections'), findsOneWidget);
    expect(find.textContaining('Profile views'), findsNothing);
    expect(find.textContaining('Saved'), findsNothing);
    // 0 posts / 0 connections from the stubbed providers above — real
    // counts, not hardcoded reference numbers like "12" or "256".
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('shows real profile fields dynamically, never inventing missing ones',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Shivam Sharma'), findsOneWidget);
    expect(find.text('UI/UX Design'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.textContaining('Building scalable systems'), findsOneWidget);
  });

  testWidgets('settings icon still navigates to the existing Settings route', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('shows "Become a Mentor" when the user has no mentor profile yet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(mentor: null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Become a Mentor'), findsOneWidget);
    expect(find.text('Mentor Profile'), findsNothing);

    await tester.tap(find.text('Become a Mentor'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('shows "Mentor Profile" with status when the user already has one', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mentor = Mentor(
      profileId: 'user-1',
      available: true,
      expertise: ['Java', 'System Design'],
    );
    await tester.pumpWidget(_harness(mentor: mentor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Mentor Profile'), findsOneWidget);
    expect(find.text('Become a Mentor'), findsNothing);
    expect(find.text('Accepting mentees'), findsOneWidget);
    expect(find.textContaining('Java'), findsOneWidget);
  });

  testWidgets('tapping an existing Mentor Profile card offers Edit/View/Pause options', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mentor = Mentor(profileId: 'user-1', available: true, expertise: ['Java']);
    await tester.pumpWidget(_harness(mentor: mentor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Mentor Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Mentorship'), findsOneWidget);
    expect(find.text('View Mentor Profile'), findsOneWidget);
    expect(find.text('Pause Mentorship'), findsOneWidget);
  });
}
