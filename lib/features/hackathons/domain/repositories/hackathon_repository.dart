import '../entities/hackathon.dart';

abstract class HackathonRepository {
  Future<List<Hackathon>> listHackathons({int limit = 20, int offset = 0});
  Future<Hackathon> getHackathon(String id);
  Future<TeamRequirement> getTeamRequirement(String teamRequirementId);

  /// Resolves [name] to an existing hackathon id (case-insensitive), or
  /// creates one if it doesn't exist yet — there is no separate "host a
  /// hackathon" step, this is the only way a hackathon row comes to exist.
  Future<String> getOrCreateHackathon(String name, {DateTime? eventDate});

  Future<List<TeamRequirement>> listTeamRequirements(String hackathonId);

  /// [skillIds] is "skills we're looking for" (existing
  /// `hackathon_team_required_skills`); [skillsHaveIds] is the new "skills
  /// we already have" table; [roles] are the new structured "Looking For"
  /// role requirements, each with its own skill list.
  Future<TeamRequirement> createTeamRequirement(
    Map<String, dynamic> data,
    List<String> skillIds, {
    List<String> skillsHaveIds = const [],
    List<TeamRoleRequirement> roles = const [],
  });

  /// Creator-only. `null` for [skillIds]/[skillsHaveIds]/[roles] leaves that
  /// part of the team unchanged; a non-null value fully replaces it —
  /// mirrors the create-or-update pattern used elsewhere in the app.
  Future<void> updateTeamRequirement(
    String teamRequirementId,
    Map<String, dynamic> data, {
    List<String>? skillIds,
    List<String>? skillsHaveIds,
    List<TeamRoleRequirement>? roles,
  });

  /// Owner-only. Removes someone other than the owner from the team.
  Future<void> removeMember(String teamRequirementId, String profileId);

  /// The team (if any) the caller already belongs to within [hackathonId] —
  /// enforces "one team per hackathon" in the UI (spec section 4).
  Future<String?> myTeamIdForHackathon(String hackathonId);

  // --- Invitations: team owner -> user ---
  Future<void> sendTeamInvitation(
      {required String teamRequirementId,
      required String receiverId,
      String? message});
  Future<List<Map<String, dynamic>>> getMyTeamInvitations(String profileId);
  Future<void> respondToInvitation(String invitationId, {required bool accept});

  // --- Join requests: user -> team owner ---
  Future<String> requestToJoinTeam(String teamRequirementId, {String? message});
  Future<void> cancelJoinRequest(String requestId);
  Future<void> respondToJoinRequest(String requestId, {required bool accept});
  Future<Set<String>> myPendingJoinRequestTeamIds(String hackathonId);

  // --- Team management: leave / delete / chat ---

  /// A team member (never the owner — they delete instead) leaves the team.
  /// Also revokes their access to the team's chat, server-side.
  Future<void> leaveTeam(String teamRequirementId);

  /// Owner-only. Deletes the team, its membership, its chat and every
  /// related record (cascades server-side — see migration 0028).
  Future<void> deleteTeam(String teamRequirementId);

  /// The team's private group chat conversation id, or null if the caller
  /// isn't a member (RLS-filtered) or the team hasn't been given a chat yet.
  Future<String?> getTeamConversationId(String teamRequirementId);
}
