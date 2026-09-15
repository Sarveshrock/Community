// Locks down resolveCommunityAction — the single source of truth for what
// the Community Detail page's primary CTA shows, mirroring
// resolveTeamCardAction (hackathons feature)'s precedent.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/communities/domain/community_action.dart';
import 'package:community_app/features/communities/domain/entities/community.dart';

Community _community({String ownerId = 'owner-1', String accessType = 'public'}) {
  return Community(
    id: 'c1',
    ownerId: ownerId,
    name: 'Test Community',
    slug: 'test-community',
    accessType: accessType,
  );
}

void main() {
  test('signed-out viewer sees none', () {
    expect(
      resolveCommunityAction(community: _community(), myId: null, isMember: false, hasPendingRequest: false),
      CommunityAction.none,
    );
  });

  test('the owner sees owner, never a join CTA', () {
    expect(
      resolveCommunityAction(community: _community(ownerId: 'me'), myId: 'me', isMember: false, hasPendingRequest: false),
      CommunityAction.owner,
    );
  });

  test('an existing member sees member', () {
    expect(
      resolveCommunityAction(community: _community(), myId: 'me', isMember: true, hasPendingRequest: false),
      CommunityAction.member,
    );
  });

  test('a pending join request shows requestPending, not requestToJoin', () {
    expect(
      resolveCommunityAction(
        community: _community(accessType: 'request_to_join'),
        myId: 'me',
        isMember: false,
        hasPendingRequest: true,
      ),
      CommunityAction.requestPending,
    );
  });

  test('a request_to_join community with no pending request shows requestToJoin', () {
    expect(
      resolveCommunityAction(
        community: _community(accessType: 'request_to_join'),
        myId: 'me',
        isMember: false,
        hasPendingRequest: false,
      ),
      CommunityAction.requestToJoin,
    );
  });

  test('a private community shows notAvailable', () {
    expect(
      resolveCommunityAction(community: _community(accessType: 'private'), myId: 'me', isMember: false, hasPendingRequest: false),
      CommunityAction.notAvailable,
    );
  });

  test('a public community with nothing blocking shows join', () {
    expect(
      resolveCommunityAction(community: _community(), myId: 'me', isMember: false, hasPendingRequest: false),
      CommunityAction.join,
    );
  });

  test('join and requestToJoin are actionable; every other state is not', () {
    expect(CommunityAction.join.isActionable, isTrue);
    expect(CommunityAction.requestToJoin.isActionable, isTrue);
    for (final state in [
      CommunityAction.none,
      CommunityAction.owner,
      CommunityAction.member,
      CommunityAction.requestPending,
      CommunityAction.notAvailable,
    ]) {
      expect(state.isActionable, isFalse, reason: '$state should not be actionable');
    }
  });
}
