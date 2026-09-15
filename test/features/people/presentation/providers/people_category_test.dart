// Locks down the mapping between the UI category chip and the two real
// backend concepts it can mean: a `primary_user_type` enum value, or (for
// Fresher, which isn't a `user_type` value — see 0002_enums.sql) a max
// experience threshold. Getting either wrong silently shows the wrong
// people for a whole category.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/people/presentation/providers/people_providers.dart';

void main() {
  test('All has no user_type and no experience ceiling', () {
    expect(PeopleCategory.all.userTypeValue, isNull);
    expect(PeopleCategory.all.maxExperienceMonths, isNull);
  });

  test('Developer/Professional/Student/Job Seeker map to real user_type enum values', () {
    expect(PeopleCategory.developer.userTypeValue, 'developer');
    expect(PeopleCategory.professional.userTypeValue, 'professional');
    expect(PeopleCategory.student.userTypeValue, 'student');
    expect(PeopleCategory.jobSeeker.userTypeValue, 'job_seeker');
  });

  test('Fresher is experience-based, not a fabricated user_type value', () {
    expect(PeopleCategory.fresher.userTypeValue, isNull);
    expect(PeopleCategory.fresher.maxExperienceMonths, 0);
  });

  test('every category has a distinct, human-readable label', () {
    final labels = PeopleCategory.values.map((c) => c.label).toSet();
    expect(labels.length, PeopleCategory.values.length);
    expect(labels, contains('Job Seeker'));
  });
}
