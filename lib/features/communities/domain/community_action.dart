import 'entities/community.dart';

/// What the Community Detail page's primary CTA should show for the
/// current viewer — pure function of community + viewer state, mirroring
/// `resolveTeamCardAction` (hackathons feature)'s precedent.
enum CommunityAction {
  /// Not signed in — nothing actionable.
  none,

  /// The viewer owns this community.
  owner,

  /// Already a member (covers moderators too — role-specific controls live
  /// in the Members section, not as a different primary CTA).
  member,

  /// A join request is awaiting the owner's response.
  requestPending,

  /// access_type == 'request_to_join' and the viewer hasn't asked yet.
  requestToJoin,

  /// access_type == 'public' — nothing blocking.
  join,

  /// access_type == 'private' — not directly joinable.
  notAvailable,
}

CommunityAction resolveCommunityAction({
  required Community community,
  required String? myId,
  required bool isMember,
  required bool hasPendingRequest,
}) {
  if (myId == null) return CommunityAction.none;
  if (community.isOwner(myId)) return CommunityAction.owner;
  if (isMember) return CommunityAction.member;
  if (hasPendingRequest) return CommunityAction.requestPending;
  if (community.accessType == 'private') return CommunityAction.notAvailable;
  if (community.accessType == 'request_to_join') return CommunityAction.requestToJoin;
  return CommunityAction.join;
}

extension CommunityActionLabel on CommunityAction {
  String get label => switch (this) {
        CommunityAction.none => '',
        CommunityAction.owner => '',
        CommunityAction.member => '',
        CommunityAction.requestPending => 'Request pending',
        CommunityAction.requestToJoin => 'Request to join',
        CommunityAction.join => 'Join community',
        CommunityAction.notAvailable => 'Not available',
      };

  bool get isActionable => this == CommunityAction.join || this == CommunityAction.requestToJoin;
}
