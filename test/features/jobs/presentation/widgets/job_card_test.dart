// Renders JobCard with worst-case data (a long title, long company name,
// long location, many skills) at every phone width the redesign brief
// calls out.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/jobs/domain/entities/job.dart';
import 'package:community_app/features/jobs/presentation/widgets/job_card.dart';

final _job = Job(
  id: 'job-1',
  posterId: 'poster-1',
  companyName: 'A Very Long International Technology Company Name Ltd.',
  title: 'Senior Staff Principal Full-Stack Platform Engineering Lead',
  employmentType: JobEmploymentType.fullTime,
  workMode: WorkMode.hybrid,
  location: 'San Francisco Bay Area, California, United States',
  salaryMin: 180000,
  salaryMax: 260000,
  currency: 'USD',
  payPeriod: PayPeriod.yearly,
  requiredSkillNames: const ['Dart', 'Flutter', 'PostgreSQL', 'Kubernetes'],
  createdAt: DateTime.now().subtract(const Duration(days: 3)),
);

Widget _harness(double width) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: SizedBox(width: width, child: JobCard(job: _job, onTap: () {}))),
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
    testWidgets('JobCard lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = Size(entry.value, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(entry.value));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
