import '../report_target.dart';

abstract class ReportRepository {
  /// Reporter identity is never exposed to the reported party — enforced by
  /// RLS, not by this interface (spec section 72).
  Future<void> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportCategory category,
    String? details,
  });
}
