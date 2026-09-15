enum UserType {
  student,
  developer,
  professional,
  jobSeeker,
  founder,
  researcher,
  other
}

extension UserTypeX on UserType {
  String get value => switch (this) {
        UserType.jobSeeker => 'job_seeker',
        _ => name,
      };

  String get label => switch (this) {
        UserType.student => 'Student',
        UserType.developer => 'Developer',
        UserType.professional => 'Professional',
        UserType.jobSeeker => 'Job Seeker',
        UserType.founder => 'Founder',
        UserType.researcher => 'Researcher',
        UserType.other => 'Other',
      };

  static UserType fromValue(String? value) {
    return UserType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserType.other,
    );
  }
}
