import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/people/domain/repositories/people_repository.dart';

void main() {
  group('PeopleFilters', () {
    test('isEmpty is true only when every field is unset, including maxExperienceMonths', () {
      expect(const PeopleFilters().isEmpty, isTrue);
      expect(const PeopleFilters(maxExperienceMonths: 0).isEmpty, isFalse);
    });

    test('copyWith only overrides the fields passed, leaving the rest untouched', () {
      const base = PeopleFilters(query: 'flutter', city: 'Pune');
      final withCategory = base.copyWith(userType: 'developer');

      expect(withCategory.query, 'flutter');
      expect(withCategory.city, 'Pune');
      expect(withCategory.userType, 'developer');
      expect(withCategory.maxExperienceMonths, isNull);
    });

    test('copyWith can layer maxExperienceMonths on top of an existing query', () {
      const base = PeopleFilters(query: 'ai');
      final fresher = base.copyWith(maxExperienceMonths: 0);

      expect(fresher.query, 'ai');
      expect(fresher.maxExperienceMonths, 0);
      expect(fresher.userType, isNull);
    });
  });
}
