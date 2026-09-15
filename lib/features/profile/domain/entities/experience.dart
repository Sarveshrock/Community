enum EmploymentType {
  fullTime,
  partTime,
  internship,
  contract,
  freelance,
  other
}

extension EmploymentTypeX on EmploymentType {
  String get value => switch (this) {
        EmploymentType.fullTime => 'full_time',
        EmploymentType.partTime => 'part_time',
        _ => name,
      };

  String get label => switch (this) {
        EmploymentType.fullTime => 'Full-time',
        EmploymentType.partTime => 'Part-time',
        EmploymentType.internship => 'Internship',
        EmploymentType.contract => 'Contract',
        EmploymentType.freelance => 'Freelance',
        EmploymentType.other => 'Other',
      };

  static EmploymentType fromValue(String? value) {
    return EmploymentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EmploymentType.fullTime,
    );
  }
}

class Experience {
  const Experience({
    required this.id,
    required this.companyName,
    required this.role,
    this.employmentType = EmploymentType.fullTime,
    required this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.description,
  });

  final String id;
  final String companyName;
  final String role;
  final EmploymentType employmentType;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCurrent;
  final String? description;

  factory Experience.fromJson(Map<String, dynamic> json) => Experience(
        id: json['id'] as String,
        companyName: json['company_name'] as String,
        role: json['role'] as String,
        employmentType:
            EmploymentTypeX.fromValue(json['employment_type'] as String?),
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'] as String)
            : null,
        isCurrent: json['is_current'] as bool? ?? false,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toInsertJson(String profileId) => {
        'profile_id': profileId,
        'company_name': companyName,
        'role': role,
        'employment_type': employmentType.value,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate?.toIso8601String().substring(0, 10),
        'is_current': isCurrent,
        'description': description,
      };
}
