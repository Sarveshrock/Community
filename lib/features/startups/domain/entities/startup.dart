class Startup {
  const Startup({
    required this.id,
    required this.ownerId,
    required this.name,
    this.logoUrl,
    this.description,
    this.industry,
    this.stage = 'idea',
    this.location,
    this.website,
    this.teamSize,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? logoUrl;
  final String? description;
  final String? industry;
  final String stage;
  final String? location;
  final String? website;
  final int? teamSize;

  factory Startup.fromJson(Map<String, dynamic> json) => Startup(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        logoUrl: json['logo_url'] as String?,
        description: json['description'] as String?,
        industry: json['industry'] as String?,
        stage: json['stage'] as String? ?? 'idea',
        location: json['location'] as String?,
        website: json['website'] as String?,
        teamSize: (json['team_size'] as num?)?.toInt(),
      );
}

class StartupOpportunity {
  const StartupOpportunity({
    required this.id,
    required this.startupId,
    required this.title,
    this.description,
    this.role,
    this.compensationType = 'negotiable',
    this.isRemote = true,
    this.status = 'open',
    this.startupName,
  });

  final String id;
  final String startupId;
  final String title;
  final String? description;
  final String? role;
  final String compensationType;
  final bool isRemote;
  final String status;
  final String? startupName;

  factory StartupOpportunity.fromJson(Map<String, dynamic> json) =>
      StartupOpportunity(
        id: json['id'] as String,
        startupId: json['startup_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        role: json['role'] as String?,
        compensationType: json['compensation_type'] as String? ?? 'negotiable',
        isRemote: json['is_remote'] as bool? ?? true,
        status: json['status'] as String? ?? 'open',
        startupName:
            (json['startups'] as Map<String, dynamic>?)?['name'] as String?,
      );
}
