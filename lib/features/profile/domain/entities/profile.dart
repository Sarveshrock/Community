import '../../../../core/models/interest.dart';
import '../../../../core/models/skill.dart';
import '../../../../core/models/user_type.dart';

/// Who may see a profile's *real* photo — the owner viewing their own
/// profile always sees it regardless of this setting (see
/// `can_view_profile_photo()` in 0049_profile_photo_privacy.sql, the single
/// place — server-side — that actually enforces this).
enum ProfilePhotoVisibility { everyone, connections, onlyMe }

extension ProfilePhotoVisibilityX on ProfilePhotoVisibility {
  String get value => switch (this) {
        ProfilePhotoVisibility.everyone => 'everyone',
        ProfilePhotoVisibility.connections => 'connections',
        ProfilePhotoVisibility.onlyMe => 'only_me',
      };

  String get label => switch (this) {
        ProfilePhotoVisibility.everyone => 'Everyone',
        ProfilePhotoVisibility.connections => 'Connections Only',
        ProfilePhotoVisibility.onlyMe => 'Only Me',
      };

  String get description => switch (this) {
        ProfilePhotoVisibility.everyone => 'Anyone on Communeo can see your photo.',
        ProfilePhotoVisibility.connections => 'Only people you\'re connected with can see your photo.',
        ProfilePhotoVisibility.onlyMe => 'Only you can see your photo.',
      };

  static ProfilePhotoVisibility fromValue(String? value) {
    return switch (value) {
      'connections' => ProfilePhotoVisibility.connections,
      'only_me' => ProfilePhotoVisibility.onlyMe,
      _ => ProfilePhotoVisibility.everyone,
    };
  }
}

class Profile {
  const Profile({
    required this.id,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.bio,
    this.city,
    this.country,
    this.primaryUserType = UserType.other,
    this.currentCompany,
    this.currentRole,
    this.totalItExperienceMonths = 0,
    this.isOpenToWork = false,
    this.isOpenToInternship = false,
    this.isOpenToFreelance = false,
    this.isOpenToMentorship = false,
    this.professionalDiscoverable = true,
    this.localDiscoverable = false,
    this.photoVisibility = ProfilePhotoVisibility.everyone,
    this.appIconStyle = 'classic',
    this.profileCompleted = false,
    this.college,
    this.degree,
    this.fieldOfStudy,
    this.graduationYear,
    this.careerGoals,
    this.availability,
    this.skills = const [],
    this.interests = const [],
    this.updatedAt,
  });

  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? country;
  final UserType primaryUserType;
  final String? currentCompany;
  final String? currentRole;
  final int totalItExperienceMonths;
  final bool isOpenToWork;
  final bool isOpenToInternship;
  final bool isOpenToFreelance;
  final bool isOpenToMentorship;
  final bool professionalDiscoverable;
  final bool localDiscoverable;

  /// Who else may see [avatarUrl]'s real image — see
  /// `can_view_profile_photo()`. Never bypass this by reading [avatarUrl]
  /// directly for someone else's profile; render through `UserAvatar`.
  final ProfilePhotoVisibility photoVisibility;

  /// Key into `kAppIconStyles` (Settings > Appearance > App Icon) — an
  /// appearance preference, unrelated to [photoVisibility].
  final String appIconStyle;

  final bool profileCompleted;
  final String? college;
  final String? degree;
  final String? fieldOfStudy;
  final int? graduationYear;
  final String? careerGoals;
  final String? availability;
  final List<ProfileSkill> skills;
  final List<Interest> interests;

  /// Server-managed audit timestamp, bumped by the existing
  /// `handle_updated_at()` trigger on every profile write — reused as a
  /// presence proxy (see `BuddyPresence`) rather than a real last-seen
  /// system, exactly like the Buddies screen already does.
  final DateTime? updatedAt;

  String get displayName => fullName?.isNotEmpty == true
      ? fullName!
      : (username ?? 'Community member');

  String get headline {
    if (currentRole != null && currentCompany != null) {
      return '$currentRole at $currentCompany';
    }
    return currentRole ?? primaryUserType.label;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      primaryUserType:
          UserTypeX.fromValue(json['primary_user_type'] as String?),
      currentCompany: json['current_company'] as String?,
      currentRole: json['current_role'] as String?,
      totalItExperienceMonths:
          (json['total_it_experience_months'] as num?)?.toInt() ?? 0,
      isOpenToWork: json['is_open_to_work'] as bool? ?? false,
      isOpenToInternship: json['is_open_to_internship'] as bool? ?? false,
      isOpenToFreelance: json['is_open_to_freelance'] as bool? ?? false,
      isOpenToMentorship: json['is_open_to_mentorship'] as bool? ?? false,
      professionalDiscoverable:
          json['professional_discoverable'] as bool? ?? true,
      localDiscoverable: json['local_discoverable'] as bool? ?? false,
      photoVisibility:
          ProfilePhotoVisibilityX.fromValue(json['photo_visibility'] as String?),
      appIconStyle: json['app_icon_style'] as String? ?? 'classic',
      profileCompleted: json['profile_completed'] as bool? ?? false,
      college: json['college'] as String?,
      degree: json['degree'] as String?,
      fieldOfStudy: json['field_of_study'] as String?,
      graduationYear: (json['graduation_year'] as num?)?.toInt(),
      careerGoals: json['career_goals'] as String?,
      availability: json['availability'] as String?,
      skills: (json['profile_skills'] as List<dynamic>?)
              ?.map((e) => ProfileSkill.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      interests: (json['profile_interests'] as List<dynamic>?)
              ?.map((e) =>
                  Interest.fromJson(e['interests'] as Map<String, dynamic>))
              .toList() ??
          const [],
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Profile copyWith({
    String? username,
    String? fullName,
    String? avatarUrl,
    String? bio,
    String? city,
    String? country,
    UserType? primaryUserType,
    String? currentCompany,
    String? currentRole,
    int? totalItExperienceMonths,
    bool? isOpenToWork,
    bool? isOpenToInternship,
    bool? isOpenToFreelance,
    bool? isOpenToMentorship,
    bool? professionalDiscoverable,
    bool? localDiscoverable,
    ProfilePhotoVisibility? photoVisibility,
    String? appIconStyle,
    bool? profileCompleted,
    String? college,
    String? degree,
    String? fieldOfStudy,
    int? graduationYear,
    String? careerGoals,
    String? availability,
  }) {
    return Profile(
      id: id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      country: country ?? this.country,
      primaryUserType: primaryUserType ?? this.primaryUserType,
      currentCompany: currentCompany ?? this.currentCompany,
      currentRole: currentRole ?? this.currentRole,
      totalItExperienceMonths:
          totalItExperienceMonths ?? this.totalItExperienceMonths,
      isOpenToWork: isOpenToWork ?? this.isOpenToWork,
      isOpenToInternship: isOpenToInternship ?? this.isOpenToInternship,
      isOpenToFreelance: isOpenToFreelance ?? this.isOpenToFreelance,
      isOpenToMentorship: isOpenToMentorship ?? this.isOpenToMentorship,
      professionalDiscoverable:
          professionalDiscoverable ?? this.professionalDiscoverable,
      localDiscoverable: localDiscoverable ?? this.localDiscoverable,
      photoVisibility: photoVisibility ?? this.photoVisibility,
      appIconStyle: appIconStyle ?? this.appIconStyle,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      college: college ?? this.college,
      degree: degree ?? this.degree,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      graduationYear: graduationYear ?? this.graduationYear,
      careerGoals: careerGoals ?? this.careerGoals,
      availability: availability ?? this.availability,
      skills: skills,
      interests: interests,
      updatedAt: updatedAt,
    );
  }
}
