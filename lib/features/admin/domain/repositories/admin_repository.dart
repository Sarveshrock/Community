import '../../../moderation/domain/report_target.dart';
import '../entities/report.dart';

abstract class AdminRepository {
  /// Whether the given profile currently holds an elevated (admin/moderator)
  /// role. Backed by the server-side `is_admin()` function via `user_roles`
  /// — role grants themselves are never trusted from client input (spec
  /// section 73).
  Future<bool> isAdmin(String profileId);

  Future<List<Report>> listReports(
      {ReportStatus? status, int limit = 50, int offset = 0});

  Future<void> updateReportStatus(String reportId, ReportStatus status);

  Future<void> recordAction({
    String? reportId,
    required ReportTargetType targetType,
    required String targetId,
    required String action,
    String? notes,
  });

  Future<List<ModerationAction>> listActionsForTarget(
      ReportTargetType targetType, String targetId);
}
