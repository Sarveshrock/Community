/// Mirrors `report_target_type` in supabase/migrations/0018_reports_moderation.sql.
enum ReportTargetType {
  profile,
  message,
  job,
  project,
  hackathon,
  community,
  startup,
  event,
  post,
  referralOffer,
  interviewPracticeProfile,
}

extension ReportTargetTypeX on ReportTargetType {
  String get value => switch (this) {
        ReportTargetType.referralOffer => 'referral_offer',
        ReportTargetType.interviewPracticeProfile => 'interview_practice_profile',
        _ => name,
      };

  static ReportTargetType fromValue(String value) =>
      ReportTargetType.values.firstWhere((t) => t.value == value,
          orElse: () => ReportTargetType.profile);
}

/// Mirrors `report_category` in supabase/migrations/0018_reports_moderation.sql.
enum ReportCategory {
  spam,
  harassment,
  fakeProfile,
  scam,
  inappropriateContent,
  unsafeBehavior,
  fraud,
  other,
}

extension ReportCategoryX on ReportCategory {
  String get value => switch (this) {
        ReportCategory.fakeProfile => 'fake_profile',
        ReportCategory.inappropriateContent => 'inappropriate_content',
        ReportCategory.unsafeBehavior => 'unsafe_behavior',
        _ => name,
      };

  String get label => switch (this) {
        ReportCategory.spam => 'Spam',
        ReportCategory.harassment => 'Harassment',
        ReportCategory.fakeProfile => 'Fake profile',
        ReportCategory.scam => 'Scam',
        ReportCategory.inappropriateContent => 'Inappropriate content',
        ReportCategory.unsafeBehavior => 'Unsafe behavior',
        ReportCategory.fraud => 'Fraud',
        ReportCategory.other => 'Other',
      };

  static ReportCategory fromValue(String value) =>
      ReportCategory.values.firstWhere(
        (c) => c.value == value,
        orElse: () => ReportCategory.other,
      );
}

/// Mirrors `report_status` in supabase/migrations/0002_enums.sql.
enum ReportStatus { open, reviewing, resolved, dismissed }

extension ReportStatusX on ReportStatus {
  String get value => name;

  String get label => switch (this) {
        ReportStatus.open => 'Open',
        ReportStatus.reviewing => 'Reviewing',
        ReportStatus.resolved => 'Resolved',
        ReportStatus.dismissed => 'Dismissed',
      };

  static ReportStatus fromValue(String value) => ReportStatus.values
      .firstWhere((s) => s.value == value, orElse: () => ReportStatus.open);
}
