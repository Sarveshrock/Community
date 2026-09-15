// Locks down TeamRequirement.fromJson's nested-relation parsing
// (hackathon_team_members / hackathon_team_required_skills) — a mismatch
// here means member counts and required-skill chips silently go blank.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/hackathons/domain/entities/hackathon.dart';

void main() {
  test('TeamRequirement.fromJson parses members and required skills', () {
    final team = TeamRequirement.fromJson({
      'id': 'team-1',
      'hackathon_id': 'hack-1',
      'creator_id': 'creator-1',
      'team_name': 'Nebula',
      'description': 'Building something cool',
      'required_roles': ['Designer', 'Backend dev'],
      'team_size': 4,
      'status': 'open',
      'profiles': {'full_name': 'Ada'},
      'hackathon_team_members': [
        {'profile_id': 'creator-1'},
        {'profile_id': 'member-2'},
      ],
      'hackathon_team_required_skills': [
        {
          'skills': {'name': 'Flutter'},
        },
        {
          'skills': {'name': 'PostgreSQL'},
        },
      ],
    });

    expect(team.creatorName, 'Ada');
    expect(team.memberIds, ['creator-1', 'member-2']);
    expect(team.memberCount, 2);
    expect(team.requiredSkillNames, ['Flutter', 'PostgreSQL']);
    expect(team.isMember('member-2'), isTrue);
    expect(team.isMember('someone-else'), isFalse);
    expect(team.openSlots, 2);
    expect(team.isFull, isFalse);
    expect(team.isOpen, isTrue);
  });

  test('TeamRequirement.fromJson tolerates missing nested relations', () {
    final team = TeamRequirement.fromJson({
      'id': 'team-2',
      'hackathon_id': 'hack-1',
      'creator_id': 'creator-1',
      'team_name': 'Solo start',
      'team_size': 2,
    });

    expect(team.memberIds, isEmpty);
    expect(team.requiredSkillNames, isEmpty);
    expect(team.status, 'open');
  });

  test('isFull reflects both explicit status and member count', () {
    final byStatus = TeamRequirement.fromJson({
      'id': 't',
      'hackathon_id': 'h',
      'creator_id': 'c',
      'team_name': 'T',
      'team_size': 10,
      'status': 'full',
    });
    expect(byStatus.isFull, isTrue);

    final byCount = TeamRequirement.fromJson({
      'id': 't2',
      'hackathon_id': 'h',
      'creator_id': 'c',
      'team_name': 'T2',
      'team_size': 1,
      'hackathon_team_members': [
        {'profile_id': 'c'},
      ],
    });
    expect(byCount.isFull, isTrue);
  });

  test('isOwner is true only for the creator', () {
    final team = TeamRequirement.fromJson({
      'id': 't',
      'hackathon_id': 'h',
      'creator_id': 'creator-1',
      'team_name': 'T',
      'team_size': 4,
    });
    expect(team.isOwner('creator-1'), isTrue);
    expect(team.isOwner('someone-else'), isFalse);
    expect(team.isOwner(null), isFalse);
  });

  test('members carries joined profile info for the Team Members section', () {
    final team = TeamRequirement.fromJson({
      'id': 't',
      'hackathon_id': 'h',
      'creator_id': 'creator-1',
      'team_name': 'T',
      'team_size': 4,
      'hackathon_team_members': [
        {
          'profile_id': 'creator-1',
          'joined_at': '2026-01-01T00:00:00Z',
          'profiles': {
            'full_name': 'Ada Lovelace',
            'avatar_url': 'https://example.com/a.png',
            'current_role': 'Engineer',
            'current_company': 'Analytical Co',
          },
        },
        // A profile RLS filters out (not professional_discoverable, not the
        // caller) comes back with profile_id but no nested `profiles`.
        {'profile_id': 'hidden-member', 'joined_at': '2026-01-02T00:00:00Z'},
      ],
    });

    expect(team.members, hasLength(2));
    final owner = team.members.first;
    expect(owner.profileId, 'creator-1');
    expect(owner.displayName, 'Ada Lovelace');
    expect(owner.headline, 'Engineer at Analytical Co');
    expect(owner.avatarUrl, 'https://example.com/a.png');

    final hidden = team.members.last;
    expect(hidden.profileId, 'hidden-member');
    expect(hidden.displayName, 'Team member');
    expect(hidden.headline, isNull);
  });

  group('0046_hackathon_team_details.sql fields', () {
    test('a team posted before this migration still parses cleanly, new sections simply absent', () {
      final team = TeamRequirement.fromJson({
        'id': 'team-old',
        'hackathon_id': 'hack-1',
        'creator_id': 'creator-1',
        'team_name': 'Legacy Team',
        'description': 'An old team row.',
        'required_roles': ['Designer'],
        'team_size': 4,
      });

      expect(team.tagline, isNull);
      expect(team.projectStage, isNull);
      expect(team.minTeamSize, isNull);
      expect(team.commitment, isNull);
      expect(team.preferredTimes, isNull);
      expect(team.timezone, isNull);
      expect(team.collaborationMode, 'online');
      expect(team.location, isNull);
      expect(team.communicationPlatform, isNull);
      expect(team.preferredExperienceLevel, isNull);
      expect(team.teamCulture, isEmpty);
      expect(team.expectations, isNull);
      expect(team.hasProjectLinks, isFalse);
      expect(team.visibility, 'public');
      expect(team.roleRequirements, isEmpty);
      expect(team.skillsHaveNames, isEmpty);
      expect(team.statusLabel, 'Looking for members');
      // Falls back to the flat legacy roles list since roleRequirements is empty.
      expect(team.requiredRoles, ['Designer']);
    });

    test('maps a fully populated row, including structured roles and their own skills', () {
      final team = TeamRequirement.fromJson({
        'id': 'team-new',
        'hackathon_id': 'hack-1',
        'creator_id': 'creator-1',
        'team_name': 'Team Nova',
        'tagline': 'AI-powered developer productivity',
        'description': 'Building an AI copilot for hackathon teams.',
        'project_stage': 'Prototype',
        'team_size': 4,
        'min_team_size': 3,
        'commitment': 'Full hackathon',
        'preferred_times': 'Weekdays 7-10 PM',
        'timezone': 'IST',
        'collaboration_mode': 'hybrid',
        'location': 'Bengaluru',
        'communication_platform': 'Discord',
        'preferred_experience_level': 'Intermediate',
        'team_culture': ['Beginner friendly', 'Learning focused'],
        'expectations': 'Commit 8-10 hours during the hackathon.',
        'github_url': 'https://github.com/example/nova',
        'visibility': 'connections_only',
        'hackathon_team_role_requirements': [
          {
            'id': 'role-1',
            'team_requirement_id': 'team-new',
            'role_name': 'AI/ML Engineer',
            'priority': 'High',
            'experience_level': 'Intermediate',
            'sort_order': 0,
            'hackathon_team_role_required_skills': [
              {
                'skills': {'name': 'Python'},
              },
            ],
          },
        ],
        'hackathon_team_skills_have': [
          {
            'skills': {'name': 'React'},
          },
        ],
        'hackathon_team_required_skills': [
          {
            'skills': {'name': 'FastAPI'},
          },
        ],
      });

      expect(team.tagline, 'AI-powered developer productivity');
      expect(team.projectStage, 'Prototype');
      expect(team.minTeamSize, 3);
      expect(team.commitment, 'Full hackathon');
      expect(team.collaborationMode, 'hybrid');
      expect(team.isHybrid, isTrue);
      expect(team.location, 'Bengaluru');
      expect(team.communicationPlatform, 'Discord');
      expect(team.teamCulture, ['Beginner friendly', 'Learning focused']);
      expect(team.hasProjectLinks, isTrue);
      expect(team.visibility, 'connections_only');
      expect(team.roleRequirements, hasLength(1));
      expect(team.roleRequirements.first.roleName, 'AI/ML Engineer');
      expect(team.roleRequirements.first.skillNames, ['Python']);
      expect(team.skillsHaveNames, ['React']);
      expect(team.requiredSkillNames, ['FastAPI']);
    });

    test('statusLabel reflects derived state, not just the raw status column', () {
      TeamRequirement team({String status = 'open', int teamSize = 4, List<Map<String, dynamic>> members = const []}) =>
          TeamRequirement.fromJson({
            'id': 't',
            'hackathon_id': 'h',
            'creator_id': 'c',
            'team_name': 'T',
            'team_size': teamSize,
            'status': status,
            'hackathon_team_members': members,
          });

      expect(team().statusLabel, 'Looking for members');
      expect(
          team(teamSize: 2, members: [
            {'profile_id': 'a'},
          ]).statusLabel,
          'Almost full');
      expect(
          team(teamSize: 1, members: [
            {'profile_id': 'a'},
          ]).statusLabel,
          'Full');
      expect(team(status: 'closed').statusLabel, 'Not accepting members');
    });
  });
}
