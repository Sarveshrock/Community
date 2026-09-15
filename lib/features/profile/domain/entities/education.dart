class Education {
  const Education({
    required this.id,
    required this.institution,
    this.degree,
    this.fieldOfStudy,
    this.startYear,
    this.endYear,
    this.isCurrent = false,
  });

  final String id;
  final String institution;
  final String? degree;
  final String? fieldOfStudy;
  final int? startYear;
  final int? endYear;
  final bool isCurrent;

  factory Education.fromJson(Map<String, dynamic> json) => Education(
        id: json['id'] as String,
        institution: json['institution'] as String,
        degree: json['degree'] as String?,
        fieldOfStudy: json['field_of_study'] as String?,
        startYear: (json['start_year'] as num?)?.toInt(),
        endYear: (json['end_year'] as num?)?.toInt(),
        isCurrent: json['is_current'] as bool? ?? false,
      );

  Map<String, dynamic> toInsertJson(String profileId) => {
        'profile_id': profileId,
        'institution': institution,
        'degree': degree,
        'field_of_study': fieldOfStudy,
        'start_year': startYear,
        'end_year': endYear,
        'is_current': isCurrent,
      };
}
