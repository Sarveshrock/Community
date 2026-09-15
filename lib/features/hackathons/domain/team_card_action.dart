import 'entities/hackathon.dart';

/// What a team card should show for the current viewer (spec section 5).
/// Purely a function of team + viewer state — the UI never guesses.
enum TeamCardAction {
  /// Not signed in — nothing actionable.
  none,

  /// The viewer owns this team: manage invitations instead of joining.
  inviteMembers,

  /// The viewer is already on this exact team.
  alreadyMember,

  /// The viewer already belongs to a *different* team in this hackathon —
  /// the one-team-per-hackathon rule (spec section 4).
  cannotJoinOtherTeam,

  /// The viewer has a join request awaiting the owner's response.
  requestPending,

  /// Team status is 'closed' or otherwise not accepting anyone.
  closed,

  /// At capacity.
  full,

  /// Nothing blocking — show "Join Team".
  join,
}

TeamCardAction resolveTeamCardAction({
  required TeamRequirement team,
  required String? myId,
  required bool hasPendingRequestForThisTeam,
  required String? myTeamIdInHackathon,
}) {
  if (myId == null) return TeamCardAction.none;
  if (team.creatorId == myId) return TeamCardAction.inviteMembers;
  if (team.isMember(myId)) return TeamCardAction.alreadyMember;
  if (myTeamIdInHackathon != null && myTeamIdInHackathon != team.id) {
    return TeamCardAction.cannotJoinOtherTeam;
  }
  if (hasPendingRequestForThisTeam) return TeamCardAction.requestPending;
  if (team.status == 'closed') return TeamCardAction.closed;
  if (team.isFull) return TeamCardAction.full;
  return TeamCardAction.join;
}

extension TeamCardActionLabel on TeamCardAction {
  String get label => switch (this) {
        TeamCardAction.none => '',
        TeamCardAction.inviteMembers => 'Invite',
        TeamCardAction.alreadyMember => 'Already a member',
        TeamCardAction.cannotJoinOtherTeam => 'On another team',
        TeamCardAction.requestPending => 'Request pending',
        TeamCardAction.closed => 'Not accepting members',
        TeamCardAction.full => 'Team full',
        TeamCardAction.join => 'Join team',
      };

  bool get isEnabled =>
      this == TeamCardAction.join || this == TeamCardAction.inviteMembers;
}
