// Renders PersonCard with worst-case data (a long name, many skills, and a
// recommendation badge all at once) at every phone width the People
// redesign spec calls out — the classic place a "name + right-aligned
// badge/presence/connect column" layout silently overflows on a narrow
// screen. Auth doesn't need stubbing here: with no signed-in user,
// `connectionWithProvider`/`myPetNamesProvider` resolve to null/empty
// without ever touching a repository (see connection_providers.dart), so
// the card still renders its default "Connect" state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/core/models/skill.dart';
import 'package:community_app/core/models/user_type.dart';
import 'package:community_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:community_app/features/people/presentation/widgets/person_card.dart';
import 'package:community_app/features/profile/domain/entities/profile.dart';

final _profile = Profile(
  id: 'user-1',
  fullName: 'Alexandria Wolfeschlegelsteinhausenbergerdorff',
  currentRole: 'Senior Full Stack Software Development Engineer',
  currentCompany: 'A Very Long International Technology Corporation Ltd',
  primaryUserType: UserType.developer,
  totalItExperienceMonths: 62,
  updatedAt: DateTime.now(),
  skills: const [
    ProfileSkill(skill: Skill(id: '1', name: 'Flutter'), level: ExperienceLevel.advanced),
    ProfileSkill(skill: Skill(id: '2', name: 'Dart'), level: ExperienceLevel.advanced),
    ProfileSkill(skill: Skill(id: '3', name: 'React'), level: ExperienceLevel.intermediate),
    ProfileSkill(skill: Skill(id: '4', name: 'Node.js'), level: ExperienceLevel.intermediate),
    ProfileSkill(skill: Skill(id: '5', name: 'Machine Learning'), level: ExperienceLevel.beginner),
    ProfileSkill(skill: Skill(id: '6', name: 'Kubernetes'), level: ExperienceLevel.beginner),
    ProfileSkill(skill: Skill(id: '7', name: 'Docker'), level: ExperienceLevel.beginner),
    ProfileSkill(skill: Skill(id: '8', name: 'Swift'), level: ExperienceLevel.beginner),
  ],
);

Widget _harness(Widget child, double width) {
  return ProviderScope(
    overrides: [authStateProvider.overrideWith((ref) => const Stream.empty())],
    child: MaterialApp(
      home: Scaffold(body: SizedBox(width: width, child: child)),
    ),
  );
}

void main() {
  const widths = <String, double>{
    'very small phone (320)': 320,
    'small Android (360)': 360,
    'iPhone SE-ish (375)': 375,
    'iPhone 12/13 (390)': 390,
    'large phone (414)': 414,
    'large phone (430)': 430,
  };

  for (final entry in widths.entries) {
    testWidgets('PersonCard lays out with no overflow on ${entry.key}, in Recommended mode',
        (tester) async {
      tester.view.physicalSize = Size(entry.value, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(
        PersonCard(profile: _profile, matchScore: 87, matchReason: 'Shared skills'),
        entry.value,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('+2'), findsOneWidget); // 8 skills, cap 6 -> "+2"
    });

    testWidgets('PersonCard lays out with no overflow on ${entry.key}, in All mode (no badge)',
        (tester) async {
      tester.view.physicalSize = Size(entry.value, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(PersonCard(profile: _profile), entry.value));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a fresher with zero experience shows no experience line and no crash',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const fresher = Profile(id: 'user-2', fullName: 'New Grad', totalItExperienceMonths: 0);
    await tester.pumpWidget(_harness(const PersonCard(profile: fresher), 320));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('mo'), findsNothing);
  });
}
