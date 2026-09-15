import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/core/utils/formatters.dart';

void main() {
  group('Formatters.experienceFromMonths', () {
    test('handles zero/negative as "less than a year"', () {
      expect(Formatters.experienceFromMonths(0), 'Less than a year');
      expect(Formatters.experienceFromMonths(-1), 'Less than a year');
    });

    test('formats months-only under a year', () {
      expect(Formatters.experienceFromMonths(6), '6 mo');
    });

    test('formats whole years', () {
      expect(Formatters.experienceFromMonths(12), '1 yr');
      expect(Formatters.experienceFromMonths(24), '2 yrs');
    });

    test('formats years and months', () {
      expect(Formatters.experienceFromMonths(14), '1 yr 2 mo');
      expect(Formatters.experienceFromMonths(30), '2 yrs 6 mo');
    });
  });

  group('Formatters.salaryRange', () {
    test('handles both null', () {
      expect(Formatters.salaryRange(null, null, 'USD'), 'Not disclosed');
    });

    test('formats a full range', () {
      expect(Formatters.salaryRange(50000, 70000, 'USD'), 'USD 50000 - 70000');
    });

    test('formats a single bound', () {
      expect(Formatters.salaryRange(50000, null, 'USD'), 'USD 50000');
      expect(Formatters.salaryRange(null, 70000, 'USD'), 'USD 70000');
    });

    test('defaults currency to USD when omitted', () {
      expect(Formatters.salaryRange(50000, null, null), 'USD 50000');
    });
  });
}
