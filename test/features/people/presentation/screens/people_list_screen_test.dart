// Verifies the actual interaction model the whole redesign is about: the
// category chip and the All/Recommended tab are independent — switching
// one never resets the other (spec sections 33/34/38/43). Both selectors
// are exercised through the real screen (tapping a chip, tapping a tab),
// not just the provider layer people_providers_test.dart already covers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/people/domain/repositories/people_repository.dart';
import 'package:community_app/features/people/presentation/providers/people_providers.dart';
import 'package:community_app/features/people/presentation/screens/people_list_screen.dart';

class _FakePeopleRepository implements PeopleRepository {
  PeopleFilters? lastSearchFilters;
  String? lastRecommendationsUserType;

  @override
  Future<List<Profile>> search(PeopleFilters filters, {int limit = 20, int offset = 0}) async {
    lastSearchFilters = filters;
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> getAiRecommendations({
    int limit = 20,
    String? userType,
    int? maxExperienceMonths,
  }) async {
    lastRecommendationsUserType = userType;
    return const [];
  }
}

void main() {
  late _FakePeopleRepository fake;

  Widget harness() {
    fake = _FakePeopleRepository();
    return ProviderScope(
      overrides: [peopleRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: PeopleListScreen()),
    );
  }

  const phoneSizes = <String, Size>{
    'very small phone (320x568)': Size(320, 568),
    'iPhone 12/13 (390x844)': Size(390, 844),
    'large phone (430x932)': Size(430, 932),
  };

  for (final entry in phoneSizes.entries) {
    testWidgets('People screen lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Find and connect with amazing people'), findsOneWidget);
      for (final category in PeopleCategory.values) {
        // "All" is both a category chip and the first tab's label, so it
        // legitimately renders twice; everything else is unique.
        final expected = category == PeopleCategory.all ? findsNWidgets(2) : findsOneWidget;
        expect(find.text(category.label), expected);
      }
      expect(find.widgetWithText(Tab, 'All'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Recommended'), findsOneWidget);
    });
  }

  testWidgets('selecting Developer then switching to Recommended keeps Developer selected',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Developer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(fake.lastSearchFilters?.userType, 'developer');

    await tester.tap(find.widgetWithText(Tab, 'Recommended'));
    await tester.pumpAndSettle();

    expect(fake.lastRecommendationsUserType, 'developer');
    expect(find.text('No recommended Developers found'), findsOneWidget);
  });

  testWidgets('changing category while on Recommended keeps Recommended selected (not reset to All)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.widgetWithText(Tab, 'Recommended'));
    await tester.pumpAndSettle();

    final studentChip = find.text('Student');
    await tester.ensureVisible(studentChip);
    await tester.pumpAndSettle();
    await tester.tap(studentChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.lastRecommendationsUserType, 'student');
    expect(find.text('No recommended Students found'), findsOneWidget);
  });
}
