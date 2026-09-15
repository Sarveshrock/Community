class Formatters {
  Formatters._();

  /// Converts total months of experience into a human string, e.g. "2 yrs 3 mo".
  static String experienceFromMonths(int months) {
    if (months <= 0) return 'Less than a year';
    final years = months ~/ 12;
    final remMonths = months % 12;
    if (years == 0) return '$remMonths mo';
    if (remMonths == 0) return '$years yr${years > 1 ? 's' : ''}';
    return '$years yr${years > 1 ? 's' : ''} $remMonths mo';
  }

  static String currency(num? amount, String? currencyCode) {
    if (amount == null) return '';
    final code = currencyCode ?? 'USD';
    return '$code ${amount.toStringAsFixed(0)}';
  }

  static String salaryRange(num? min, num? max, String? currencyCode) {
    if (min == null && max == null) return 'Not disclosed';
    final code = currencyCode ?? 'USD';
    if (min != null && max != null) {
      return '$code ${min.toStringAsFixed(0)} - ${max.toStringAsFixed(0)}';
    }
    return currency(min ?? max, code);
  }
}
