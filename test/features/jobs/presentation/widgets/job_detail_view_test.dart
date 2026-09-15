// Renders JobDetailView — the shared rendering used by both the real Job
// Detail screen and the Job Builder's live Preview — with every optional
// section populated (worst case for overflow) at every phone width the
// redesign brief calls out, plus a check that an old, minimal job (only
// the original 9 fields) renders every new section as simply absent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/core/models/skill.dart';
import 'package:community_app/features/jobs/domain/entities/job.dart';
import 'package:community_app/features/jobs/domain/job_action_state.dart';
import 'package:community_app/features/jobs/presentation/widgets/job_detail_view.dart';

final _fullJob = Job(
  id: 'job-1',
  posterId: 'poster-1',
  companyName: 'A Very Long International Technology Company Name Ltd.',
  companyWebsite: 'https://example.com',
  companyDescription: 'We build large-scale distributed systems for millions of users worldwide.',
  title: 'Senior Staff Principal Full-Stack Platform Engineering Lead',
  jobCategory: 'Software Engineering',
  description: 'A long, detailed description of the role and what the day-to-day looks like.',
  employmentType: JobEmploymentType.fullTime,
  workMode: WorkMode.hybrid,
  location: 'San Francisco Bay Area, California, United States',
  city: 'San Francisco',
  state: 'California',
  country: 'United States',
  expectedOfficeDays: '3 days/week',
  responsibilities: const ['Own the platform roadmap', 'Mentor a team of engineers', 'Drive architecture reviews'],
  experienceLevel: ExperienceLevel.advanced,
  experienceMinMonths: 60,
  experienceMaxMonths: 96,
  education: "Bachelor's or Master's in Computer Science",
  prerequisites: 'Strong distributed systems background',
  salaryMin: 180000,
  salaryMax: 260000,
  currency: 'USD',
  payPeriod: PayPeriod.yearly,
  salaryNegotiable: true,
  bonusInfo: 'Up to 20% annual bonus',
  equityInfo: '0.2% vested over 4 years',
  benefits: const ['Health insurance', 'Paid leave', 'Learning budget', 'Stock options'],
  applicationMethod: JobApplicationMethod.communeo,
  applicationInstructions: 'Apply with your GitHub and a short note.',
  resumeRequired: true,
  portfolioRequired: true,
  coverLetterRequired: true,
  contactInfo: 'careers@example.com',
  deadline: DateTime.now().add(const Duration(days: 30)),
  createdAt: DateTime.now(),
  requiredSkillNames: const ['Dart', 'Flutter', 'PostgreSQL', 'Kubernetes'],
  preferredSkillNames: const ['GraphQL', 'gRPC'],
);

final _minimalJob = Job(
  id: 'job-old',
  posterId: 'poster-1',
  companyName: 'Old Co',
  title: 'Legacy role',
  description: 'An old job row from before this redesign.',
  employmentType: JobEmploymentType.fullTime,
  workMode: WorkMode.remote,
  location: 'Remote',
  createdAt: DateTime(2024, 1, 1),
);

Widget _harness(Job job, {JobActionState? actionState}) {
  return MaterialApp(
    home: Scaffold(body: JobDetailView(job: job, actionState: actionState)),
  );
}

void main() {
  const widths = <String, Size>{
    'very small phone (320x568)': Size(320, 568),
    'small Android (360x800)': Size(360, 800),
    'iPhone SE-ish (375x812)': Size(375, 812),
    'iPhone 12/13 (390x844)': Size(390, 844),
    'large phone (414x896)': Size(414, 896),
    'large phone (430x932)': Size(430, 932),
  };

  for (final entry in widths.entries) {
    testWidgets('JobDetailView (fully populated) lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(_fullJob, actionState: JobActionState.applyInternal));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Scroll to the bottom to force every lazily-built section into
      // existence — an overflow further down the list would otherwise go
      // unnoticed since off-screen sliver children aren't built at all.
      await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a fully populated job renders every optional section', (tester) async {
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_fullJob, actionState: JobActionState.applyInternal));
    await tester.pump();

    expect(find.text('Responsibilities'), findsOneWidget);
    expect(find.text('Requirements'), findsOneWidget);
    expect(find.text('Nice to have'), findsOneWidget);
    expect(find.text('Compensation'), findsOneWidget);
    expect(find.text('Benefits'), findsOneWidget);
    expect(find.text('About the company'), findsOneWidget);
  });

  testWidgets('an old, minimal job renders with every new section simply absent, never a "null"', (tester) async {
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_minimalJob));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('null'), findsNothing);
    expect(find.text('Responsibilities'), findsNothing);
    expect(find.text('Nice to have'), findsNothing);
    expect(find.text('Benefits'), findsNothing);
    expect(find.text('About the company'), findsNothing);
    // Base fields from before the redesign still render.
    expect(find.text('Legacy role'), findsOneWidget);
    expect(find.text('Old Co'), findsOneWidget);
  });
}
