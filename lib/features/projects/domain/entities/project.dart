enum CollaborationType {
  personal,
  startup,
  openSource,
  research,
  hackathon,
  other
}

extension CollaborationTypeX on CollaborationType {
  String get value => switch (this) {
        CollaborationType.openSource => 'open_source',
        _ => name,
      };
  String get label => switch (this) {
        CollaborationType.personal => 'Personal',
        CollaborationType.startup => 'Startup',
        CollaborationType.openSource => 'Open Source',
        CollaborationType.research => 'Research',
        CollaborationType.hackathon => 'Hackathon',
        CollaborationType.other => 'Other',
      };
  static CollaborationType fromValue(String? value) {
    return CollaborationType.values.firstWhere((e) => e.value == value,
        orElse: () => CollaborationType.personal);
  }
}

enum CompensationType { paid, unpaid, equity, negotiable }

extension CompensationTypeX on CompensationType {
  String get value => name;
  String get label => switch (this) {
        CompensationType.paid => 'Paid',
        CompensationType.unpaid => 'Unpaid',
        CompensationType.equity => 'Equity',
        CompensationType.negotiable => 'Negotiable',
      };
  static CompensationType fromValue(String? value) {
    return CompensationType.values.firstWhere((e) => e.value == value,
        orElse: () => CompensationType.unpaid);
  }
}

class Project {
  const Project({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.category,
    this.collaborationType = CollaborationType.personal,
    this.compensationType = CompensationType.unpaid,
    this.compensationDetails,
    this.timeCommitmentHours,
    this.durationDescription,
    this.status = 'open',
    required this.createdAt,
    this.requiredSkillNames = const [],
  });

  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String? category;
  final CollaborationType collaborationType;
  final CompensationType compensationType;
  final String? compensationDetails;
  final int? timeCommitmentHours;
  final String? durationDescription;
  final String status;
  final DateTime createdAt;
  final List<String> requiredSkillNames;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        category: json['category'] as String?,
        collaborationType:
            CollaborationTypeX.fromValue(json['collaboration_type'] as String?),
        compensationType:
            CompensationTypeX.fromValue(json['compensation_type'] as String?),
        compensationDetails: json['compensation_details'] as String?,
        timeCommitmentHours: (json['time_commitment_hours'] as num?)?.toInt(),
        durationDescription: json['duration_description'] as String?,
        status: json['status'] as String? ?? 'open',
        createdAt: DateTime.parse(json['created_at'] as String),
        requiredSkillNames: (json['project_required_skills'] as List<dynamic>?)
                ?.map((e) => (e['skills']?['name']) as String?)
                .whereType<String>()
                .toList() ??
            const [],
      );
}
