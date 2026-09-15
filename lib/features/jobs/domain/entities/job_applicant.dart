/// One applicant on a job, from the poster's point of view
/// (`getApplicationsForJob`) — replaces the previous raw
/// `Map<String, dynamic>` shape for type safety.
class JobApplicant {
  const JobApplicant({
    required this.applicationId,
    required this.profileId,
    this.fullName,
    this.avatarUrl,
    this.currentRole,
    required this.status,
    this.coverMessage,
    this.resumePath,
    this.portfolioPath,
    this.githubUrl,
    this.linkedinUrl,
    required this.createdAt,
  });

  final String applicationId;
  final String profileId;
  final String? fullName;
  final String? avatarUrl;
  final String? currentRole;
  final String status;
  final String? coverMessage;
  final String? resumePath;
  final String? portfolioPath;
  final String? githubUrl;
  final String? linkedinUrl;
  final DateTime createdAt;

  factory JobApplicant.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return JobApplicant(
      applicationId: json['id'] as String,
      profileId: json['profile_id'] as String,
      fullName: profile?['full_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      currentRole: profile?['current_role'] as String?,
      status: json['status'] as String? ?? 'submitted',
      coverMessage: json['cover_message'] as String?,
      resumePath: json['resume_path'] as String?,
      portfolioPath: json['portfolio_path'] as String?,
      githubUrl: json['github_url'] as String?,
      linkedinUrl: json['linkedin_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
