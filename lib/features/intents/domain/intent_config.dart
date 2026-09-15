import 'package:flutter/material.dart' show IconData, Icons;

import '../../hackathons/domain/entities/hackathon.dart'
    show kCommitmentOptions, kCollaborationModes, kProjectStages, kTeamRoleOptions, collaborationModeLabel;
import '../../jobs/domain/entities/job.dart' show JobEmploymentType, JobEmploymentTypeX;
import '../../mentorship/domain/entities/mentor.dart' show kMentorshipTopics, CommunicationMode;
import 'entities/intent.dart';

/// One dynamic field an [IntentConfiguration] asks for. Purely descriptive —
/// no widget code lives here — so the same spec drives both the Create/Edit
/// form (build the right input) and the Detail page (render the right
/// label/value), and adding a new [IntentType] later only means adding one
/// more [IntentConfiguration] below, never touching the form or detail
/// screen's code (the "extensibility requirement").
enum IntentFieldKind { text, multilineText, dropdown, multiSelect, number }

class IntentFieldSpec {
  const IntentFieldSpec({
    required this.key,
    required this.label,
    required this.kind,
    this.hint,
    this.options = const [],
  });

  /// The key this field is stored under in [UserIntent.metadata].
  final String key;
  final String label;
  final IntentFieldKind kind;
  final String? hint;

  /// Choices for [IntentFieldKind.dropdown]/[IntentFieldKind.multiSelect].
  final List<String> options;
}

/// Everything the Create/Edit form and Detail page need to render one
/// [IntentType]'s dynamic section — a title, an icon, and its field specs.
class IntentConfiguration {
  const IntentConfiguration({required this.icon, required this.sectionTitle, this.fields = const []});

  final IconData icon;
  final String sectionTitle;
  final List<IntentFieldSpec> fields;
}

const _industryOptions = <String>[
  'Technology',
  'Finance',
  'Healthcare',
  'Education',
  'E-commerce',
  'Gaming',
  'Media',
  'Consulting',
  'Government',
  'Other',
];

const _formatOptions = <String>['Chat', 'Video call', 'Voice call', 'In-person'];

/// The single source of truth mapping an [IntentType] to its dynamic
/// section — reused as-is by the Create/Edit form and the Detail page.
/// Several enum values intentionally share one configuration (e.g. every
/// "find X collaborator/contributor" flavor) rather than each getting a
/// near-duplicate copy.
IntentConfiguration intentTypeConfig(IntentType type) {
  switch (type) {
    case IntentType.findCollaborator:
    case IntentType.findDeveloper:
    case IntentType.findDesigner:
    case IntentType.findOpenSourceContributor:
    case IntentType.findResearchCollaborator:
    case IntentType.offerCollaboration:
      return IntentConfiguration(
        icon: Icons.diversity_3_outlined,
        sectionTitle: 'Collaboration details',
        fields: [
          const IntentFieldSpec(key: 'building', label: 'What are you building?', kind: IntentFieldKind.multilineText),
          const IntentFieldSpec(
            key: 'collaboration_type',
            label: 'Collaboration type',
            kind: IntentFieldKind.dropdown,
            options: ['Project', 'Startup', 'Open Source', 'Research', 'Hackathon', 'Freelance', 'Other'],
          ),
          const IntentFieldSpec(key: 'project_stage', label: 'Project stage', kind: IntentFieldKind.dropdown, options: kProjectStages),
          const IntentFieldSpec(key: 'role_needed', label: 'Role needed', kind: IntentFieldKind.dropdown, options: kTeamRoleOptions),
          const IntentFieldSpec(key: 'team_size', label: 'Expected team size', kind: IntentFieldKind.number),
          const IntentFieldSpec(key: 'current_team_size', label: 'Current team size (optional)', kind: IntentFieldKind.number),
          const IntentFieldSpec(key: 'timeline', label: 'Timeline', kind: IntentFieldKind.text, hint: 'e.g. 2 months'),
          IntentFieldSpec(
              key: 'collaboration_mode',
              label: 'Collaboration mode',
              kind: IntentFieldKind.dropdown,
              options: [for (final m in kCollaborationModes) collaborationModeLabel(m)]),
        ],
      );

    case IntentType.findProject:
      return IntentConfiguration(
        icon: Icons.rocket_launch_outlined,
        sectionTitle: 'Project details',
        fields: [
          const IntentFieldSpec(
            key: 'project_type',
            label: 'Project type',
            kind: IntentFieldKind.dropdown,
            options: ['Open source', 'Startup', 'Research', 'Personal', 'Freelance', 'Other'],
          ),
          const IntentFieldSpec(key: 'interested_in', label: 'What are you interested in building?', kind: IntentFieldKind.multilineText),
          const IntentFieldSpec(key: 'project_stage', label: 'Project stage', kind: IntentFieldKind.dropdown, options: kProjectStages),
          const IntentFieldSpec(key: 'role_needed', label: 'Preferred role', kind: IntentFieldKind.dropdown, options: kTeamRoleOptions),
          const IntentFieldSpec(key: 'timeline', label: 'Timeline', kind: IntentFieldKind.text),
          const IntentFieldSpec(key: 'team_size', label: 'Team size', kind: IntentFieldKind.number),
          const IntentFieldSpec(
              key: 'visibility_pref', label: 'Open source or private?', kind: IntentFieldKind.dropdown, options: ['Open source', 'Private']),
          IntentFieldSpec(
              key: 'collaboration_mode',
              label: 'Collaboration mode',
              kind: IntentFieldKind.dropdown,
              options: [for (final m in kCollaborationModes) collaborationModeLabel(m)]),
        ],
      );

    case IntentType.findJob:
    case IntentType.findInternship:
    case IntentType.findStartupOpportunity:
      return IntentConfiguration(
        icon: Icons.work_outline_rounded,
        sectionTitle: 'Job search details',
        fields: [
          const IntentFieldSpec(key: 'desired_role', label: 'Desired job role', kind: IntentFieldKind.text),
          IntentFieldSpec(
            key: 'employment_type',
            label: 'Employment type',
            kind: IntentFieldKind.dropdown,
            options: [for (final t in JobEmploymentType.values) t.label],
          ),
          const IntentFieldSpec(key: 'salary_range', label: 'Expected salary range (optional)', kind: IntentFieldKind.text, hint: 'e.g. 8-12 LPA'),
          const IntentFieldSpec(key: 'notice_period', label: 'Notice period (optional)', kind: IntentFieldKind.text, hint: 'e.g. 30 days'),
          const IntentFieldSpec(
              key: 'relocation', label: 'Open to relocation?', kind: IntentFieldKind.dropdown, options: ['Yes', 'No', 'Depends on offer']),
          const IntentFieldSpec(key: 'industry', label: 'Preferred industry (optional)', kind: IntentFieldKind.dropdown, options: _industryOptions),
          const IntentFieldSpec(
              key: 'company_size',
              label: 'Preferred company size (optional)',
              kind: IntentFieldKind.dropdown,
              options: ['Startup', 'Mid-size', 'Enterprise', 'No preference']),
        ],
      );

    case IntentType.findMentor:
      return IntentConfiguration(
        icon: Icons.school_outlined,
        sectionTitle: 'Mentorship goals',
        fields: [
          const IntentFieldSpec(key: 'mentorship_goal', label: 'What do you want mentorship for?', kind: IntentFieldKind.multilineText),
          const IntentFieldSpec(
            key: 'help_needed',
            label: 'What kind of help do you need?',
            kind: IntentFieldKind.multiSelect,
            options: kMentorshipTopics,
          ),
          const IntentFieldSpec(
              key: 'preferred_mentor_experience',
              label: 'Preferred mentor experience',
              kind: IntentFieldKind.dropdown,
              options: ['Any', 'Intermediate', 'Advanced', 'Expert']),
          const IntentFieldSpec(
              key: 'mentorship_format', label: 'Mentorship format', kind: IntentFieldKind.dropdown, options: ['1:1', 'Group', 'Either']),
          IntentFieldSpec(
              key: 'session_preference',
              label: 'Session preference',
              kind: IntentFieldKind.multiSelect,
              options: CommunicationMode.values.map(CommunicationMode.label).toList()),
          const IntentFieldSpec(
              key: 'pricing_preference', label: 'Free / Paid preference', kind: IntentFieldKind.dropdown, options: ['Free only', 'Open to paid']),
          const IntentFieldSpec(key: 'availability', label: 'Preferred availability (optional)', kind: IntentFieldKind.text),
          const IntentFieldSpec(key: 'duration', label: 'Mentorship duration (optional)', kind: IntentFieldKind.text, hint: 'e.g. 3 months'),
        ],
      );

    case IntentType.offerMentorship:
      return const IntentConfiguration(
        icon: Icons.workspace_premium_outlined,
        sectionTitle: 'What you can mentor on',
        fields: [
          IntentFieldSpec(key: 'can_mentor_on', label: 'What can you mentor?', kind: IntentFieldKind.multilineText),
          IntentFieldSpec(
              key: 'expertise_level', label: 'Your expertise level', kind: IntentFieldKind.dropdown, options: ['Intermediate', 'Advanced', 'Expert']),
          IntentFieldSpec(key: 'years_experience', label: 'Years of experience', kind: IntentFieldKind.number),
          IntentFieldSpec(key: 'can_help_with', label: 'What can you help with?', kind: IntentFieldKind.multiSelect, options: kMentorshipTopics),
          IntentFieldSpec(
              key: 'mentorship_format', label: 'Mentorship format', kind: IntentFieldKind.dropdown, options: ['1:1', 'Group', 'Either']),
          IntentFieldSpec(key: 'pricing', label: 'Free / Paid', kind: IntentFieldKind.dropdown, options: ['Free', 'Paid']),
          IntentFieldSpec(key: 'session_duration', label: 'Session duration (optional)', kind: IntentFieldKind.text, hint: 'e.g. 45 minutes'),
          IntentFieldSpec(key: 'availability', label: 'Availability (optional)', kind: IntentFieldKind.text),
          IntentFieldSpec(
              key: 'preferred_mentee_experience',
              label: 'Preferred mentee experience level',
              kind: IntentFieldKind.dropdown,
              options: ['Any', 'Beginner', 'Intermediate', 'Advanced']),
        ],
      );

    case IntentType.findHackathonTeam:
    case IntentType.findHackathonTeammates:
      return IntentConfiguration(
        icon: Icons.emoji_events_outlined,
        sectionTitle: 'Hackathon team details',
        fields: [
          const IntentFieldSpec(key: 'hackathon_name', label: 'Hackathon', kind: IntentFieldKind.text, hint: 'e.g. Smart India Hackathon 2026'),
          const IntentFieldSpec(key: 'role_wanted', label: 'Role wanted', kind: IntentFieldKind.dropdown, options: kTeamRoleOptions),
          const IntentFieldSpec(key: 'preferred_team_size', label: 'Preferred team size', kind: IntentFieldKind.number),
          const IntentFieldSpec(key: 'project_interests', label: 'Project interests', kind: IntentFieldKind.text, hint: 'e.g. AI, Fintech, Health-tech'),
          const IntentFieldSpec(key: 'commitment', label: 'Commitment', kind: IntentFieldKind.dropdown, options: kCommitmentOptions),
          IntentFieldSpec(
              key: 'collaboration_mode',
              label: 'Online / In-person / Hybrid',
              kind: IntentFieldKind.dropdown,
              options: [for (final m in kCollaborationModes) collaborationModeLabel(m)]),
          const IntentFieldSpec(
              key: 'preferred_teammate_experience',
              label: 'Preferred teammate experience',
              kind: IntentFieldKind.dropdown,
              options: ['Any', 'Beginner', 'Intermediate', 'Advanced']),
        ],
      );

    case IntentType.findCofounder:
      return const IntentConfiguration(
        icon: Icons.trending_up_rounded,
        sectionTitle: 'Co-founder search',
        fields: [
          IntentFieldSpec(key: 'startup_idea', label: 'Startup idea', kind: IntentFieldKind.multilineText),
          IntentFieldSpec(key: 'industry', label: 'Industry', kind: IntentFieldKind.dropdown, options: _industryOptions),
          IntentFieldSpec(key: 'startup_stage', label: 'Startup stage', kind: IntentFieldKind.dropdown, options: kProjectStages),
          IntentFieldSpec(key: 'cofounder_role', label: 'Co-founder role', kind: IntentFieldKind.text, hint: 'e.g. Technical co-founder'),
          IntentFieldSpec(
              key: 'commitment_type', label: 'Full-time / Part-time', kind: IntentFieldKind.dropdown, options: ['Full-time', 'Part-time']),
          IntentFieldSpec(
              key: 'collaboration_mode',
              label: 'Remote / Hybrid',
              kind: IntentFieldKind.dropdown,
              options: ['Remote', 'Hybrid', 'In-person']),
          IntentFieldSpec(
              key: 'preferred_cofounder_experience',
              label: 'Preferred co-founder experience',
              kind: IntentFieldKind.dropdown,
              options: ['Any', 'Intermediate', 'Advanced', 'Expert']),
          IntentFieldSpec(
              key: 'equity_discussion',
              label: 'Open to discussing equity?',
              kind: IntentFieldKind.dropdown,
              options: ['Yes', 'Prefer to discuss later', 'No']),
        ],
      );

    case IntentType.networking:
      return const IntentConfiguration(
        icon: Icons.hub_outlined,
        sectionTitle: 'Networking preferences',
        fields: [
          IntentFieldSpec(
            key: 'looking_for',
            label: 'What are you looking for?',
            kind: IntentFieldKind.multiSelect,
            options: [
              'Industry connections',
              'Career opportunities',
              'Knowledge sharing',
              'Business networking',
              'Startup networking',
              'Technical networking',
              'Community',
            ],
          ),
          IntentFieldSpec(key: 'industries', label: 'Industries', kind: IntentFieldKind.multiSelect, options: _industryOptions),
          IntentFieldSpec(key: 'networking_format', label: 'Networking format', kind: IntentFieldKind.multiSelect, options: _formatOptions),
          IntentFieldSpec(
              key: 'connection_type',
              label: 'Preferred connection type',
              kind: IntentFieldKind.dropdown,
              options: ['Peers', 'Mentors', 'Founders', 'Anyone']),
        ],
      );

    case IntentType.findStudyPartner:
      return const IntentConfiguration(
        icon: Icons.menu_book_outlined,
        sectionTitle: 'Study details',
        fields: [
          IntentFieldSpec(key: 'topic', label: 'What do you want to learn?', kind: IntentFieldKind.text),
          IntentFieldSpec(
              key: 'current_level', label: 'Current level', kind: IntentFieldKind.dropdown, options: ['Beginner', 'Intermediate', 'Advanced']),
          IntentFieldSpec(
              key: 'target_level', label: 'Target level', kind: IntentFieldKind.dropdown, options: ['Beginner', 'Intermediate', 'Advanced', 'Expert']),
          IntentFieldSpec(
              key: 'study_format', label: 'Study format', kind: IntentFieldKind.multiSelect, options: _formatOptions),
          IntentFieldSpec(key: 'availability', label: 'Availability', kind: IntentFieldKind.text, hint: 'e.g. Weekends'),
          IntentFieldSpec(key: 'study_duration', label: 'Study duration', kind: IntentFieldKind.text, hint: 'e.g. 2 months'),
          IntentFieldSpec(key: 'group_size', label: 'Preferred group size', kind: IntentFieldKind.number),
        ],
      );

    case IntentType.findMockInterviewPartner:
      return const IntentConfiguration(
        icon: Icons.record_voice_over_outlined,
        sectionTitle: 'Mock interview details',
        fields: [
          IntentFieldSpec(key: 'interview_topic', label: 'Interview topic / role', kind: IntentFieldKind.text, hint: 'e.g. Backend, DSA, System design'),
          IntentFieldSpec(
              key: 'interview_type',
              label: 'Interview type',
              kind: IntentFieldKind.dropdown,
              options: ['Technical', 'Behavioral', 'System design', 'Case study', 'Other']),
          IntentFieldSpec(key: 'session_format', label: 'Session format', kind: IntentFieldKind.multiSelect, options: _formatOptions),
          IntentFieldSpec(key: 'availability', label: 'Availability (optional)', kind: IntentFieldKind.text),
        ],
      );

    case IntentType.findReferral:
      return const IntentConfiguration(
        icon: Icons.forward_outlined,
        sectionTitle: 'Referral details',
        fields: [
          IntentFieldSpec(key: 'target_company', label: 'Target company', kind: IntentFieldKind.text),
          IntentFieldSpec(key: 'target_role', label: 'Target role', kind: IntentFieldKind.text),
        ],
      );

    case IntentType.offerReferral:
      return const IntentConfiguration(
        icon: Icons.card_giftcard_outlined,
        sectionTitle: 'Referral offer details',
        fields: [
          IntentFieldSpec(key: 'company', label: 'Company you can refer at', kind: IntentFieldKind.text),
          IntentFieldSpec(key: 'roles_available', label: 'Roles you can refer for (optional)', kind: IntentFieldKind.text),
        ],
      );
  }
}
