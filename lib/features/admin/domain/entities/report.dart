import '../../../moderation/domain/report_target.dart';

/// A user report as seen by moderators/admins (spec section 72-73). Only
/// visible server-side to the reporter themselves or an admin/moderator —
/// enforced by RLS (`is_admin()`), never by this client model.
class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.category,
    required this.status,
    required this.createdAt,
    this.details,
    this.reporterName,
  });

  final String id;
  final String reporterId;
  final ReportTargetType targetType;
  final String targetId;
  final ReportCategory category;
  final ReportStatus status;
  final DateTime createdAt;
  final String? details;
  final String? reporterName;

  factory Report.fromJson(Map<String, dynamic> json) {
    final reporter = json['profiles'] as Map<String, dynamic>?;
    return Report(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      targetType: ReportTargetTypeX.fromValue(json['target_type'] as String),
      targetId: json['target_id'] as String,
      category: ReportCategoryX.fromValue(json['category'] as String),
      status: ReportStatusX.fromValue(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      details: json['details'] as String?,
      reporterName: reporter?['full_name'] as String?,
    );
  }
}

/// A moderator/admin action taken on a report or piece of content.
class ModerationAction {
  const ModerationAction({
    required this.id,
    required this.moderatorId,
    required this.targetType,
    required this.targetId,
    required this.action,
    required this.createdAt,
    this.reportId,
    this.notes,
    this.moderatorName,
  });

  final String id;
  final String moderatorId;
  final ReportTargetType targetType;
  final String targetId;
  final String action;
  final DateTime createdAt;
  final String? reportId;
  final String? notes;
  final String? moderatorName;

  factory ModerationAction.fromJson(Map<String, dynamic> json) {
    final moderator = json['profiles'] as Map<String, dynamic>?;
    return ModerationAction(
      id: json['id'] as String,
      moderatorId: json['moderator_id'] as String,
      targetType: ReportTargetTypeX.fromValue(json['target_type'] as String),
      targetId: json['target_id'] as String,
      action: json['action'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      reportId: json['report_id'] as String?,
      notes: json['notes'] as String?,
      moderatorName: moderator?['full_name'] as String?,
    );
  }
}
