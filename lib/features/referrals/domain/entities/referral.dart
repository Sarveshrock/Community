enum ReferralRequestStatus {
  pending,
  accepted,
  declined,
  resumeSubmitted,
  referralSubmitted,
  interviewing,
  hired,
  rejected,
  cancelled,
}

extension ReferralRequestStatusX on ReferralRequestStatus {
  String get value => switch (this) {
        ReferralRequestStatus.resumeSubmitted => 'resume_submitted',
        ReferralRequestStatus.referralSubmitted => 'referral_submitted',
        _ => name,
      };

  String get label => switch (this) {
        ReferralRequestStatus.pending => 'Requested',
        ReferralRequestStatus.accepted => 'Accepted — submit your resume',
        ReferralRequestStatus.declined => 'Declined',
        ReferralRequestStatus.resumeSubmitted => 'Resume submitted',
        ReferralRequestStatus.referralSubmitted => 'Referral submitted',
        ReferralRequestStatus.interviewing => 'Interviewing',
        ReferralRequestStatus.hired => 'Hired',
        ReferralRequestStatus.rejected => 'Rejected',
        ReferralRequestStatus.cancelled => 'Cancelled',
      };

  static ReferralRequestStatus fromValue(String? value) {
    return ReferralRequestStatus.values.firstWhere((e) => e.value == value,
        orElse: () => ReferralRequestStatus.pending);
  }
}

/// A member advertising they can refer people at a company (spec-extension:
/// Referral Marketplace). Optional profile fields are only populated when
/// joined from a listing query.
class ReferralOffer {
  const ReferralOffer({
    required this.id,
    required this.profileId,
    required this.companyName,
    this.roleTitle,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    this.fullName,
    this.avatarUrl,
    this.currentRole,
  });

  final String id;
  final String profileId;
  final String companyName;
  final String? roleTitle;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final String? fullName;
  final String? avatarUrl;
  final String? currentRole;

  factory ReferralOffer.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ReferralOffer(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      companyName: json['company_name'] as String,
      roleTitle: json['role_title'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      currentRole: profile?['current_role'] as String?,
    );
  }
}

/// One requester's referral pipeline against a specific [ReferralOffer].
class ReferralRequest {
  const ReferralRequest({
    required this.id,
    required this.offerId,
    required this.referrerId,
    required this.requesterId,
    required this.jobTitle,
    this.jobUrl,
    this.message,
    this.resumeUrl,
    this.status = ReferralRequestStatus.pending,
    required this.createdAt,
    this.companyName,
    this.requesterName,
    this.requesterAvatarUrl,
    this.referrerName,
    this.referrerAvatarUrl,
  });

  final String id;
  final String offerId;
  final String referrerId;
  final String requesterId;
  final String jobTitle;
  final String? jobUrl;
  final String? message;
  final String? resumeUrl;
  final ReferralRequestStatus status;
  final DateTime createdAt;
  final String? companyName;
  final String? requesterName;
  final String? requesterAvatarUrl;
  final String? referrerName;
  final String? referrerAvatarUrl;

  factory ReferralRequest.fromJson(Map<String, dynamic> json) {
    final offer = json['referral_offers'] as Map<String, dynamic>?;
    final requester = json['requester'] as Map<String, dynamic>?;
    final referrer = json['referrer'] as Map<String, dynamic>?;
    return ReferralRequest(
      id: json['id'] as String,
      offerId: json['offer_id'] as String,
      referrerId: json['referrer_id'] as String,
      requesterId: json['requester_id'] as String,
      jobTitle: json['job_title'] as String,
      jobUrl: json['job_url'] as String?,
      message: json['message'] as String?,
      resumeUrl: json['resume_url'] as String?,
      status: ReferralRequestStatusX.fromValue(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      companyName: offer?['company_name'] as String?,
      requesterName: requester?['full_name'] as String?,
      requesterAvatarUrl: requester?['avatar_url'] as String?,
      referrerName: referrer?['full_name'] as String?,
      referrerAvatarUrl: referrer?['avatar_url'] as String?,
    );
  }
}
