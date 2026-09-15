/// Cross-feature reference entity — skills are attached to profiles, jobs,
/// projects, and hackathon team requirements alike.
class Skill {
  const Skill({required this.id, required this.name, this.category});

  final String id;
  final String name;
  final String? category;

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
      );
}

enum ExperienceLevel { beginner, intermediate, advanced, expert }

extension ExperienceLevelX on ExperienceLevel {
  String get label => switch (this) {
        ExperienceLevel.beginner => 'Beginner',
        ExperienceLevel.intermediate => 'Intermediate',
        ExperienceLevel.advanced => 'Advanced',
        ExperienceLevel.expert => 'Expert',
      };

  String get value => name;

  static ExperienceLevel fromValue(String? value) {
    return ExperienceLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExperienceLevel.intermediate,
    );
  }
}

class ProfileSkill {
  const ProfileSkill(
      {required this.skill, required this.level, this.yearsExperience});

  final Skill skill;
  final ExperienceLevel level;
  final double? yearsExperience;

  factory ProfileSkill.fromJson(Map<String, dynamic> json) => ProfileSkill(
        skill: Skill.fromJson(json['skills'] as Map<String, dynamic>),
        level: ExperienceLevelX.fromValue(json['experience_level'] as String?),
        yearsExperience: (json['years_experience'] as num?)?.toDouble(),
      );
}
