import '../../../../core/models/skill.dart';

enum JobEmploymentType {
  fullTime,
  internship,
  freelance,
  contract,
  partTime,
  research,
  volunteer,
  temporary,
  other,
}

extension JobEmploymentTypeX on JobEmploymentType {
  String get value => switch (this) {
        JobEmploymentType.fullTime => 'full_time',
        JobEmploymentType.partTime => 'part_time',
        _ => name,
      };
  String get label => switch (this) {
        JobEmploymentType.fullTime => 'Full-time',
        JobEmploymentType.internship => 'Internship',
        JobEmploymentType.freelance => 'Freelance',
        JobEmploymentType.contract => 'Contract',
        JobEmploymentType.partTime => 'Part-time',
        JobEmploymentType.research => 'Research',
        JobEmploymentType.volunteer => 'Volunteer',
        JobEmploymentType.temporary => 'Temporary',
        JobEmploymentType.other => 'Other',
      };
  static JobEmploymentType fromValue(String? value) {
    return JobEmploymentType.values.firstWhere((e) => e.value == value,
        orElse: () => JobEmploymentType.fullTime);
  }
}

enum WorkMode { remote, hybrid, onsite }

extension WorkModeX on WorkMode {
  String get value => name;
  String get label => switch (this) {
        WorkMode.remote => 'Remote',
        WorkMode.hybrid => 'Hybrid',
        WorkMode.onsite => 'Onsite',
      };
  static WorkMode fromValue(String? value) {
    return WorkMode.values
        .firstWhere((e) => e.value == value, orElse: () => WorkMode.remote);
  }
}

/// Reuses the shared `ExperienceLevel` enum (already used by
/// `profile_skills`) rather than a job-specific 5-tier one — the spec's
/// "Entry/Junior/Mid/Senior/Lead" collapses cleanly onto it.
extension JobExperienceLevelX on ExperienceLevel {
  String get jobLabel => switch (this) {
        ExperienceLevel.beginner => 'Entry level',
        ExperienceLevel.intermediate => 'Mid level',
        ExperienceLevel.advanced => 'Senior',
        ExperienceLevel.expert => 'Lead / Principal',
      };
}

enum PayPeriod { yearly, monthly, hourly, fixed }

extension PayPeriodX on PayPeriod {
  String get value => name;
  String get label => switch (this) {
        PayPeriod.yearly => '/ year',
        PayPeriod.monthly => '/ month',
        PayPeriod.hourly => '/ hour',
        PayPeriod.fixed => 'fixed price',
      };
  static PayPeriod fromValue(String? value) =>
      PayPeriod.values.firstWhere((e) => e.value == value, orElse: () => PayPeriod.yearly);
}

enum JobApplicationMethod { communeo, external }

extension JobApplicationMethodX on JobApplicationMethod {
  String get value => name;
  static JobApplicationMethod fromValue(String? value) => JobApplicationMethod.values
      .firstWhere((e) => e.value == value, orElse: () => JobApplicationMethod.external);
}

/// A job posting. Phase 1 fields all live directly on the row — old jobs
/// (posted before this migration) simply have every new field at its
/// default/null, and `Job.fromJson` never crashes or shows "null" for them
/// (see backward-compat test).
class Job {
  const Job({
    required this.id,
    required this.posterId,
    required this.companyName,
    this.companyLogoUrl,
    this.companyWebsite,
    this.companyDescription,
    required this.title,
    this.jobCategory,
    this.description,
    this.employmentType = JobEmploymentType.fullTime,
    this.workMode = WorkMode.remote,
    this.location,
    this.city,
    this.state,
    this.country,
    this.expectedOfficeDays,
    this.responsibilities = const [],
    this.experienceLevel,
    this.experienceMinMonths,
    this.experienceMaxMonths,
    this.education,
    this.prerequisites,
    this.salaryMin,
    this.salaryMax,
    this.currency,
    this.payPeriod,
    this.salaryVisible = true,
    this.salaryNegotiable = false,
    this.bonusInfo,
    this.equityInfo,
    this.benefits = const [],
    this.internshipDurationMonths,
    this.stipend,
    this.potentialConversion = false,
    this.noticePeriodDays,
    this.engagementDuration,
    this.hoursPerWeek,
    this.workSchedule,
    this.contractStartDate,
    this.contractEndDate,
    this.renewable = false,
    this.applicationMethod = JobApplicationMethod.external,
    this.applicationUrl,
    this.applicationInstructions,
    this.resumeRequired = false,
    this.portfolioRequired = false,
    this.coverLetterRequired = false,
    this.contactInfo,
    this.deadline,
    this.status = 'open',
    required this.createdAt,
    this.requiredSkillNames = const [],
    this.preferredSkillNames = const [],
  });

  final String id;
  final String posterId;
  final String companyName;
  final String? companyLogoUrl;
  final String? companyWebsite;
  final String? companyDescription;
  final String title;
  final String? jobCategory;
  final String? description;
  final JobEmploymentType employmentType;
  final WorkMode workMode;
  final String? location;
  final String? city;
  final String? state;
  final String? country;
  final String? expectedOfficeDays;
  final List<String> responsibilities;
  final ExperienceLevel? experienceLevel;
  final int? experienceMinMonths;
  final int? experienceMaxMonths;
  final String? education;
  final String? prerequisites;
  final num? salaryMin;
  final num? salaryMax;
  final String? currency;
  final PayPeriod? payPeriod;
  final bool salaryVisible;
  final bool salaryNegotiable;
  final String? bonusInfo;
  final String? equityInfo;
  final List<String> benefits;
  final int? internshipDurationMonths;
  final num? stipend;
  final bool potentialConversion;
  final int? noticePeriodDays;
  final String? engagementDuration;
  final int? hoursPerWeek;
  final String? workSchedule;
  final DateTime? contractStartDate;
  final DateTime? contractEndDate;
  final bool renewable;
  final JobApplicationMethod applicationMethod;
  final String? applicationUrl;
  final String? applicationInstructions;
  final bool resumeRequired;
  final bool portfolioRequired;
  final bool coverLetterRequired;
  final String? contactInfo;
  final DateTime? deadline;
  final String status;
  final DateTime createdAt;
  final List<String> requiredSkillNames;
  final List<String> preferredSkillNames;

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get isFilled => status == 'filled';
  bool get isInternalApplication => applicationMethod == JobApplicationMethod.communeo;
  bool get deadlinePassed => deadline != null && DateTime.now().isAfter(deadline!);
  bool get hasCompensationInfo => salaryVisible && (salaryMin != null || salaryMax != null);
  bool get isInternship => employmentType == JobEmploymentType.internship;

  factory Job.fromJson(Map<String, dynamic> json) => Job(
        id: json['id'] as String,
        posterId: json['poster_id'] as String,
        companyName: json['company_name'] as String,
        companyLogoUrl: json['company_logo_url'] as String?,
        companyWebsite: json['company_website'] as String?,
        companyDescription: json['company_description'] as String?,
        title: json['title'] as String,
        jobCategory: json['job_category'] as String?,
        description: json['description'] as String?,
        employmentType:
            JobEmploymentTypeX.fromValue(json['employment_type'] as String?),
        workMode: WorkModeX.fromValue(json['work_mode'] as String?),
        location: json['location'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        country: json['country'] as String?,
        expectedOfficeDays: json['expected_office_days'] as String?,
        responsibilities:
            (json['responsibilities'] as List<dynamic>?)?.cast<String>() ?? const [],
        experienceLevel: json['experience_level'] != null
            ? ExperienceLevel.values.firstWhere(
                (e) => e.name == json['experience_level'],
                orElse: () => ExperienceLevel.intermediate,
              )
            : null,
        experienceMinMonths: (json['experience_min_months'] as num?)?.toInt(),
        experienceMaxMonths: (json['experience_max_months'] as num?)?.toInt(),
        education: json['education'] as String?,
        prerequisites: json['prerequisites'] as String?,
        salaryMin: json['salary_min'] as num?,
        salaryMax: json['salary_max'] as num?,
        currency: json['currency'] as String?,
        payPeriod:
            json['pay_period'] != null ? PayPeriodX.fromValue(json['pay_period'] as String?) : null,
        salaryVisible: json['salary_visible'] as bool? ?? true,
        salaryNegotiable: json['salary_negotiable'] as bool? ?? false,
        bonusInfo: json['bonus_info'] as String?,
        equityInfo: json['equity_info'] as String?,
        benefits: (json['benefits'] as List<dynamic>?)?.cast<String>() ?? const [],
        internshipDurationMonths: (json['internship_duration_months'] as num?)?.toInt(),
        stipend: json['stipend'] as num?,
        potentialConversion: json['potential_conversion'] as bool? ?? false,
        noticePeriodDays: (json['notice_period_days'] as num?)?.toInt(),
        engagementDuration: json['engagement_duration'] as String?,
        hoursPerWeek: (json['hours_per_week'] as num?)?.toInt(),
        workSchedule: json['work_schedule'] as String?,
        contractStartDate: json['contract_start_date'] != null
            ? DateTime.parse(json['contract_start_date'] as String)
            : null,
        contractEndDate: json['contract_end_date'] != null
            ? DateTime.parse(json['contract_end_date'] as String)
            : null,
        renewable: json['renewable'] as bool? ?? false,
        applicationMethod:
            JobApplicationMethodX.fromValue(json['application_method'] as String?),
        applicationUrl: json['application_url'] as String?,
        applicationInstructions: json['application_instructions'] as String?,
        resumeRequired: json['resume_required'] as bool? ?? false,
        portfolioRequired: json['portfolio_required'] as bool? ?? false,
        coverLetterRequired: json['cover_letter_required'] as bool? ?? false,
        contactInfo: json['contact_info'] as String?,
        deadline: json['deadline'] != null
            ? DateTime.parse(json['deadline'] as String)
            : null,
        status: json['status'] as String? ?? 'open',
        createdAt: DateTime.parse(json['created_at'] as String),
        requiredSkillNames: (json['job_required_skills'] as List<dynamic>?)
                ?.map((e) => (e['skills']?['name']) as String?)
                .whereType<String>()
                .toList() ??
            const [],
        preferredSkillNames: (json['job_preferred_skills'] as List<dynamic>?)
                ?.map((e) => (e['skills']?['name']) as String?)
                .whereType<String>()
                .toList() ??
            const [],
      );
}

/// Known job categories — kept as a Dart list over a plain text column
/// (mirrors `kPostCategories`/`posts.category`), not a DB enum, so the list
/// can grow without a migration.
const kJobCategories = <String>[
  'Software Engineering',
  'Product',
  'Design',
  'Data',
  'Cybersecurity',
  'DevOps / Cloud',
  'Marketing',
  'Sales',
  'Finance',
  'HR',
  'Operations',
  'Other',
];

const kJobBenefits = <String>[
  'Health insurance',
  'Paid leave',
  'Flexible hours',
  'Remote work',
  'Learning budget',
  'Wellness benefits',
  'Relocation assistance',
  'Internet allowance',
  'Stock options',
  'Performance bonus',
];
