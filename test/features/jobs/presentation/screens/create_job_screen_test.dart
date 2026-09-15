// Renders the Job Builder at every phone size the redesign brief calls out.
// This form has several Row-based paired fields (min/max experience,
// min/max salary, city/state) — exactly the kind of layout that silently
// clips on a narrow phone, mirroring create_event_screen_test's precedent.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/jobs/domain/entities/job.dart';
import 'package:community_app/features/jobs/presentation/screens/create_job_screen.dart';
import 'package:community_app/features/profile/presentation/providers/profile_providers.dart';

Widget _harness() {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const CreateJobScreen()),
  ]);
  return ProviderScope(
    overrides: [
      allSkillsProvider.overrideWith((ref) async => const [
            Skill(id: 's1', name: 'Dart'),
            Skill(id: 's2', name: 'PostgreSQL'),
            Skill(id: 's3', name: 'Kubernetes'),
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
    testWidgets('Post a Job lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Post a Job'), findsOneWidget);
      expect(find.text('Job basics'), findsOneWidget);
      expect(find.text('Role description'), findsOneWidget);
      // Default Employment Type is Full-time, so its dynamic details
      // section is titled accordingly.
      expect(find.text('Full-time details'), findsOneWidget);
      expect(find.text('Skills'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Application settings'), findsOneWidget);
    });
  }

  Future<void> selectEmploymentType(WidgetTester tester, String label) async {
    final employmentDropdown = find.byType(DropdownButtonFormField<JobEmploymentType>);
    await tester.ensureVisible(employmentDropdown);
    await tester.pumpAndSettle();
    await tester.tap(employmentDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Full-time shows experience/salary/notice period/benefits, not internship fields', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Full-time details'), findsOneWidget);
    expect(find.widgetWithText(DropdownButtonFormField<ExperienceLevel?>, 'Experience level (optional)'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Notice period (days, optional)'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Bonus (optional)'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Equity / ESOP (optional)'), findsOneWidget);
    expect(find.text('Benefits'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Duration (months)'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Stipend'), findsNothing);
  });

  testWidgets('switching Full-time -> Internship swaps in duration/stipend/conversion fields', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.widgetWithText(TextFormField, 'Duration (months)'), findsNothing);

    await selectEmploymentType(tester, 'Internship');

    expect(find.text('Internship details'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Duration (months)'), findsOneWidget);
    expect(find.widgetWithText(SwitchListTile, 'Potential full-time conversion'), findsOneWidget);
    // Switching away from Full-time hides its own details.
    expect(find.widgetWithText(TextFormField, 'Notice period (days, optional)'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Bonus (optional)'), findsNothing);

    // Switching back to Full-time removes internship-only fields again —
    // switching types never leaks the other type's fields into view.
    await selectEmploymentType(tester, 'Full-time');
    expect(find.text('Full-time details'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Duration (months)'), findsNothing);
  });

  testWidgets('Contract shows start/end dates and renewal, not experience/notice period', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await selectEmploymentType(tester, 'Contract');

    expect(find.text('Contract details'), findsOneWidget);
    expect(find.text('Start date (optional)'), findsOneWidget);
    expect(find.text('End date (optional)'), findsOneWidget);
    expect(find.widgetWithText(SwitchListTile, 'Renewal possible'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Notice period (days, optional)'), findsNothing);
    expect(find.widgetWithText(DropdownButtonFormField<ExperienceLevel?>, 'Experience level (optional)'),
        findsNothing);
  });

  testWidgets('Volunteer shows time commitment and recognition, not salary fields', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await selectEmploymentType(tester, 'Volunteer');

    expect(find.text('Volunteer details'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Time commitment (hours/week)'), findsOneWidget);
    expect(find.text('Certificate / recognition (optional)'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Min'), findsNothing);
  });

  testWidgets('defaults to external application (matching the DB default) and switching to '
      'Communeo swaps the URL field for resume/portfolio/cover-letter toggles', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Default matches jobs.application_method's DB default ('external') so
    // old jobs (all external, pre-redesign) keep behaving identically.
    expect(find.widgetWithText(TextFormField, 'External application URL'), findsOneWidget);
    expect(find.widgetWithText(SwitchListTile, 'Require resume'), findsNothing);
    // External jobs never show the custom-questions section — those only
    // apply to the internal Communeo application flow.
    expect(find.text('Custom application questions'), findsNothing);

    final methodDropdown =
        find.widgetWithText(DropdownButtonFormField<JobApplicationMethod>, 'Apply on an external site');
    await tester.ensureVisible(methodDropdown);
    await tester.pumpAndSettle();
    await tester.tap(methodDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply on Communeo').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'External application URL'), findsNothing);
    expect(find.widgetWithText(SwitchListTile, 'Require resume'), findsOneWidget);
    expect(find.text('Custom application questions'), findsOneWidget);
  });
}
