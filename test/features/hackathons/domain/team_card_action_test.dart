// Locks down the per-card action resolution (spec section 5) — the UI must
// never show "Join Team" to someone who's already a member, already on
// another team in the same hackathon, or looking at a full/closed team.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/hackathons/domain/entities/hackathon.dart';
import 'package:community_app/features/hackathons/domain/team_card_action.dart';

TeamRequirement _team({
  String id = 'team-1',
  String creatorId = 'creator-1',
  int teamSize = 4,
  String status = 'open',
  List<String> memberIds = const ['creator-1'],
}) =>
    TeamRequirement(
      id: id,
      hackathonId: 'hack-1',
      creatorId: creatorId,
      teamName: 'Test Team',
      teamSize: teamSize,
      status: status,
      memberIds: memberIds,
    );

void main() {
  test('signed-out viewer sees no action', () {
    final action = resolveTeamCardAction(
      team: _team(),
      myId: null,
      hasPendingRequestForThisTeam: false,
      myTeamIdInHackathon: null,
    );
    expect(action, TeamCardAction.none);
  });

  test('the team owner sees inviteMembers, never join', () {
    final action = resolveTeamCardAction(
      team: _team(creatorId: 'me'),
      myId: 'me',
      hasPendingRequestForThisTeam: false,
      myTeamIdInHackathon: 'team-1',
    );
    expect(action, TeamCardAction.inviteMembers);
  });

  test('an existing member sees alreadyMember', () {
    final action = resolveTeamCardAction(
      team: _team(memberIds: const ['creator-1', 'me']),
      myId: 'me',
      hasPendingRequestForThisTeam: false,
      myTeamIdInHackathon: 'team-1',
    );
    expect(action, TeamCardAction.alreadyMember);
  });

  test('one-team-per-hackathon: already on a different team blocks joining',
      () {
    final action = resolveTeamCardAction(
      team: _team(id: 'team-2'),
      myId: 'me',
      hasPendingRequestForThisTeam: false,
      myTeamIdInHackathon: 'team-1', // a different team in the same hackathon
    );
    expect(action, TeamCardAction.cannotJoinOtherTeam);
  });

  test('a pending join request shows requestPending, not join', () {
    final action = resolveTeamCardAction(
      team: _team(),
      myId: 'me',
      hasPendingRequestForThisTeam: true,
      myTeamIdInHackathon: null,
    );
    expect(action, TeamCardAction.requestPending);
  });

  test('a closed team is not joinable even with room left', () {
    final action = resolveTeamCardAction(
      team: _team(status: 'closed'),
      myId: 'me',
      hasPendingRequestForThisTeam: false,
      myTeamIdInHackathon: null,
    );
    expect(action, TeamCardAction.closed);
  });

  test('a team at capacity shows full', () {
    final action = resolveTeamCardAction(
      team: _team(teamSize: 2, memberIds: const ['creator-1', 'someone-else']),
      myId: 'me',
      hasPendingRequestForThisTeam: false,
      myTeamIdInHackathon: null,
    );
    expect(action, TeamCardAction.full);
  });

  test('status=full is respected even if memberIds looks stale', () {
    final action = resolveTeamCardAction(
      team: _team(status: 'full', teamSize: 10, memberIds: const ['creator-1']),
      myId: 'me',
      hasPendingRequestForThisTeam: false,
      myTeamIdInHackathon: null,
    );
    expect(action, TeamCardAction.full);
  });

  test('an eligible outsider sees join', () {
    final action = resolveTeamCardAction(
      team: _team(),
      myId: 'me',
      hasPendingRequestForThisTeam: false,
      myTeamIdInHackathon: null,
    );
    expect(action, TeamCardAction.join);
  });

  test('only join and inviteMembers are enabled actions', () {
    expect(TeamCardAction.join.isEnabled, isTrue);
    expect(TeamCardAction.inviteMembers.isEnabled, isTrue);
    for (final a in [
      TeamCardAction.none,
      TeamCardAction.alreadyMember,
      TeamCardAction.cannotJoinOtherTeam,
      TeamCardAction.requestPending,
      TeamCardAction.closed,
      TeamCardAction.full,
    ]) {
      expect(a.isEnabled, isFalse, reason: '$a should not be actionable');
    }
  });
}
