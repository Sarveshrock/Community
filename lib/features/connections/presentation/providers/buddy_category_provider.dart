import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import 'connection_providers.dart';

/// The six Buddies purposes (spec-extension). Every connection is
/// classified into exactly one, using only data the app already has —
/// nothing here is a new database concept.
enum BuddyCategory { friends, mentors, mockInterview, communities, others }

extension BuddyCategoryX on BuddyCategory {
  String get label => switch (this) {
        BuddyCategory.friends => 'Friends',
        BuddyCategory.mentors => 'Mentors',
        BuddyCategory.mockInterview => 'Mock Interview',
        BuddyCategory.communities => 'Communities',
        BuddyCategory.others => 'Others',
      };
}

/// Classifies every one of the caller's accepted connections into a
/// [BuddyCategory], keyed by the *other* profile's id.
///
/// Priority order (a connection can only genuinely earn one primary label,
/// though it always still appears under "All"):
///  1. Mentors — the other profile has an active `mentor_profiles` row.
///  2. Mock Interview — the other profile is active in the practice pool.
///  3. Communities — the other profile shares a (visible-to-us) community
///     with the caller.
///  4. Friends — the other profile shares at least one interest with the
///     caller — the "you have something in common" bucket.
///  5. Others — none of the above; still a real connection, just with no
///     further signal available to categorize it by.
///
/// Every signal is read directly (no new repository layer, matching the
/// existing precedent of `communityStatsProvider`'s cross-table reads) and
/// respects existing RLS as-is — e.g. another person's *private* community
/// memberships are invisible here exactly as they are everywhere else.
final buddyCategoryMapProvider =
    FutureProvider<Map<String, BuddyCategory>>((ref) async {
  final myId = ref.watch(authStateProvider).valueOrNull?.id;
  if (myId == null) return {};

  final connections = await ref.watch(buddiesProvider.future);
  if (connections.isEmpty) return {};

  final otherIds =
      connections.map((c) => c.otherProfileId(myId)).toSet().toList();

  final myProfile = await ref.watch(myProfileProvider.future);
  final myInterests =
      myProfile?.interests.map((i) => i.name.toLowerCase()).toSet() ?? {};

  final mentorRows = await supabase
      .from(Tables.mentorProfiles)
      .select('profile_id')
      .inFilter('profile_id', otherIds)
      .eq('available', true);
  final mentorIds = {for (final r in mentorRows) r['profile_id'] as String};

  final poolRows = await supabase
      .from(Tables.interviewPracticeProfiles)
      .select('profile_id')
      .inFilter('profile_id', otherIds)
      .eq('is_active', true);
  final poolIds = {for (final r in poolRows) r['profile_id'] as String};

  final myCommunityRows = await supabase
      .from(Tables.communityMembers)
      .select('community_id')
      .eq('profile_id', myId);
  final myCommunityIds =
      {for (final r in myCommunityRows) r['community_id'] as String}.toList();

  final sharedCommunityIds = <String>{};
  if (myCommunityIds.isNotEmpty) {
    final otherCommunityRows = await supabase
        .from(Tables.communityMembers)
        .select('profile_id')
        .inFilter('profile_id', otherIds)
        .inFilter('community_id', myCommunityIds);
    sharedCommunityIds
        .addAll(otherCommunityRows.map((r) => r['profile_id'] as String));
  }

  final result = <String, BuddyCategory>{};
  for (final c in connections) {
    final otherId = c.otherProfileId(myId);
    if (mentorIds.contains(otherId)) {
      result[otherId] = BuddyCategory.mentors;
    } else if (poolIds.contains(otherId)) {
      result[otherId] = BuddyCategory.mockInterview;
    } else if (sharedCommunityIds.contains(otherId)) {
      result[otherId] = BuddyCategory.communities;
    } else if (myInterests.isNotEmpty &&
        c.otherProfileInterests
            .any((i) => myInterests.contains(i.toLowerCase()))) {
      result[otherId] = BuddyCategory.friends;
    } else {
      result[otherId] = BuddyCategory.others;
    }
  }
  return result;
});
