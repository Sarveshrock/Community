// Locks down computeTeamMatchScore — the simple, deterministic
// compatibility score (spec: "do not introduce unnecessary AI/API
// dependencies", so no edge function involved here).

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/hackathons/domain/entities/hackathon.dart';
import 'package:community_app/features/hackathons/domain/team_match.dart';

TeamRequirement _team({List<String> wanted = const [], List<TeamRoleRequirement> roles = const []}) {
  return TeamRequirement(
    id: 't',
    hackathonId: 'h',
    creatorId: 'c',
    teamName: 'T',
    requiredSkillNames: wanted,
    roleRequirements: roles,
  );
}

void main() {
  test('returns null when the team asks for no skills at all', () {
    expect(computeTeamMatchScore(team: _team(), mySkillNames: ['Python']), isNull);
  });

  test('100% when every wanted skill is matched', () {
    final result = computeTeamMatchScore(
      team: _team(wanted: ['Python', 'React']),
      mySkillNames: ['python', 'REACT', 'Extra Skill'],
    );
    expect(result, isNotNull);
    expect(result!.percent, 100);
    expect(result.matchedSkills, containsAll(['Python', 'React']));
    expect(result.missingSkills, isEmpty);
  });

  test('partial match reports both matched and missing skills', () {
    final result = computeTeamMatchScore(
      team: _team(wanted: ['Python', 'React', 'PostgreSQL']),
      mySkillNames: ['Python'],
    );
    expect(result!.percent, closeTo(33, 1));
    expect(result.matchedSkills, ['Python']);
    expect(result.missingSkills, containsAll(['React', 'PostgreSQL']));
  });

  test('0% and hasAnyMatch is false when nothing overlaps', () {
    final result = computeTeamMatchScore(team: _team(wanted: ['Rust']), mySkillNames: ['Java']);
    expect(result!.percent, 0);
    expect(result.hasAnyMatch, isFalse);
  });

  test('pools required skills from both the team level and every structured role, deduplicated', () {
    final result = computeTeamMatchScore(
      team: _team(
        wanted: ['Python'],
        roles: [
          const TeamRoleRequirement(id: 'r1', teamRequirementId: 't', roleName: 'Backend', skillNames: ['Python', 'FastAPI']),
        ],
      ),
      mySkillNames: ['Python', 'FastAPI'],
    );
    expect(result!.percent, 100);
    expect(result.matchedSkills, containsAll(['Python', 'FastAPI']));
  });
}
