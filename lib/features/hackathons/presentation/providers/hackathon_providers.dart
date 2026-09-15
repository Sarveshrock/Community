import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/hackathon_repository_impl.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/repositories/hackathon_repository.dart';

export '../../domain/entities/hackathon.dart';

final hackathonRepositoryProvider = Provider<HackathonRepository>((ref) {
  return HackathonRepositoryImpl(supabase);
});

final hackathonsListProvider = FutureProvider<List<Hackathon>>((ref) {
  return ref.watch(hackathonRepositoryProvider).listHackathons();
});

final hackathonDetailProvider =
    FutureProvider.family<Hackathon, String>((ref, id) async {
  final hackathon =
      await ref.watch(hackathonRepositoryProvider).getHackathon(id);
  ref
      .read(analyticsServiceProvider)
      .log(AnalyticsEvents.hackathonViewed, {'hackathon_id': id});
  return hackathon;
});

final teamRequirementsProvider =
    FutureProvider.family<List<TeamRequirement>, String>((ref, hackathonId) {
  return ref
      .watch(hackathonRepositoryProvider)
      .listTeamRequirements(hackathonId);
});

/// A single team requirement, with its members and their profile info —
/// backs the "Team Page" (spec section 7).
final teamDetailProvider =
    FutureProvider.family<TeamRequirement, String>((ref, teamRequirementId) {
  return ref
      .watch(hackathonRepositoryProvider)
      .getTeamRequirement(teamRequirementId);
});

/// The team's private group chat id, or null if the caller has no access to
/// it (not a member) or it hasn't been created yet.
final teamConversationIdProvider =
    FutureProvider.family<String?, String>((ref, teamRequirementId) {
  return ref
      .watch(hackathonRepositoryProvider)
      .getTeamConversationId(teamRequirementId);
});

/// The team (if any) the caller already belongs to within a hackathon —
/// drives the "one team per hackathon" UI restriction (spec section 4).
final myTeamIdForHackathonProvider =
    FutureProvider.family<String?, String>((ref, hackathonId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Future.value(null);
  return ref
      .watch(hackathonRepositoryProvider)
      .myTeamIdForHackathon(hackathonId);
});

/// Team ids the caller has an outstanding join request for, within one
/// hackathon — drives the "Request Pending" card state (spec section 5).
final myPendingJoinRequestTeamIdsProvider =
    FutureProvider.family<Set<String>, String>((ref, hackathonId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Future.value(<String>{});
  return ref
      .watch(hackathonRepositoryProvider)
      .myPendingJoinRequestTeamIds(hackathonId);
});

final myTeamInvitationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(hackathonRepositoryProvider).getMyTeamInvitations(user.id);
});

class HackathonController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _invalidateTeam(String hackathonId, {String? teamRequirementId}) {
    ref.invalidate(teamRequirementsProvider(hackathonId));
    ref.invalidate(myTeamIdForHackathonProvider(hackathonId));
    ref.invalidate(myPendingJoinRequestTeamIdsProvider(hackathonId));
    if (teamRequirementId != null) {
      ref.invalidate(teamDetailProvider(teamRequirementId));
      ref.invalidate(teamConversationIdProvider(teamRequirementId));
    }
  }

  /// Posts a team requirement. If [hackathonId] isn't already known (the
  /// user typed a hackathon name instead of navigating from an existing
  /// one), resolves/creates it by [hackathonName] first — there is no
  /// separate "host a hackathon" step (spec: never host inside the app).
  Future<bool> createTeamRequirement({
    String? hackathonId,
    String? hackathonName,
    DateTime? hackathonEventDate,
    required Map<String, dynamic> data,
    required List<String> skillIds,
    List<String> skillsHaveIds = const [],
    List<TeamRoleRequirement> roles = const [],
  }) async {
    assert(hackathonId != null ||
        (hackathonName != null && hackathonName.trim().isNotEmpty));
    state = const AsyncLoading();
    final repo = ref.read(hackathonRepositoryProvider);
    String? resolvedHackathonId = hackathonId;
    final result = await AsyncValue.guard<void>(() async {
      resolvedHackathonId ??= await repo.getOrCreateHackathon(hackathonName!,
          eventDate: hackathonEventDate);
      await repo.createTeamRequirement(
        {...data, 'hackathon_id': resolvedHackathonId},
        skillIds,
        skillsHaveIds: skillsHaveIds,
        roles: roles,
      );
    });
    state = result;
    if (!result.hasError) {
      ref.invalidate(hackathonsListProvider);
      final id = resolvedHackathonId;
      if (id != null) _invalidateTeam(id);
    }
    return !result.hasError;
  }

  /// Creator-only edit. `null` for [skillIds]/[skillsHaveIds]/[roles] leaves
  /// that part unchanged; a non-null value fully replaces it.
  Future<bool> updateTeamRequirement(
    String teamRequirementId,
    String hackathonId,
    Map<String, dynamic> data, {
    List<String>? skillIds,
    List<String>? skillsHaveIds,
    List<TeamRoleRequirement>? roles,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(hackathonRepositoryProvider).updateTeamRequirement(
            teamRequirementId,
            data,
            skillIds: skillIds,
            skillsHaveIds: skillsHaveIds,
            roles: roles,
          ),
    );
    state = result;
    if (!result.hasError) _invalidateTeam(hackathonId, teamRequirementId: teamRequirementId);
    return !result.hasError;
  }

  Future<bool> removeMember(String teamRequirementId, String profileId, String hackathonId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(hackathonRepositoryProvider).removeMember(teamRequirementId, profileId),
    );
    state = result;
    if (!result.hasError) _invalidateTeam(hackathonId, teamRequirementId: teamRequirementId);
    return !result.hasError;
  }

  Future<bool> respondToInvitation(String invitationId,
      {required bool accept, String? hackathonId}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(hackathonRepositoryProvider)
          .respondToInvitation(invitationId, accept: accept),
    );
    state = result;
    if (!result.hasError) {
      ref.invalidate(myTeamInvitationsProvider);
      if (hackathonId != null) _invalidateTeam(hackathonId);
    }
    return !result.hasError;
  }

  Future<bool> sendInvitation(
      {required String teamRequirementId,
      required String receiverId,
      String? message}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(hackathonRepositoryProvider).sendTeamInvitation(
            teamRequirementId: teamRequirementId,
            receiverId: receiverId,
            message: message,
          ),
    );
    state = result;
    if (!result.hasError) {
      ref.read(analyticsServiceProvider).log(AnalyticsEvents.teamRequest,
          {'team_requirement_id': teamRequirementId});
    }
    return !result.hasError;
  }

  Future<bool> requestToJoinTeam(String teamRequirementId, String hackathonId,
      {String? message}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(hackathonRepositoryProvider)
          .requestToJoinTeam(teamRequirementId, message: message),
    );
    state = result;
    if (!result.hasError) {
      _invalidateTeam(hackathonId);
      ref.read(analyticsServiceProvider).log(AnalyticsEvents.teamRequest,
          {'team_requirement_id': teamRequirementId});
    }
    return !result.hasError;
  }

  Future<bool> cancelJoinRequest(String requestId, String hackathonId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(hackathonRepositoryProvider).cancelJoinRequest(requestId));
    state = result;
    if (!result.hasError) _invalidateTeam(hackathonId);
    return !result.hasError;
  }

  Future<bool> respondToJoinRequest(String requestId,
      {required bool accept, String? hackathonId}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(hackathonRepositoryProvider)
          .respondToJoinRequest(requestId, accept: accept),
    );
    state = result;
    if (!result.hasError && hackathonId != null) _invalidateTeam(hackathonId);
    return !result.hasError;
  }

  Future<bool> leaveTeam(String teamRequirementId, String hackathonId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(hackathonRepositoryProvider).leaveTeam(teamRequirementId));
    state = result;
    if (!result.hasError)
      _invalidateTeam(hackathonId, teamRequirementId: teamRequirementId);
    return !result.hasError;
  }

  Future<bool> deleteTeam(String teamRequirementId, String hackathonId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(hackathonRepositoryProvider).deleteTeam(teamRequirementId));
    state = result;
    if (!result.hasError)
      _invalidateTeam(hackathonId, teamRequirementId: teamRequirementId);
    return !result.hasError;
  }
}

final hackathonControllerProvider =
    AsyncNotifierProvider<HackathonController, void>(HackathonController.new);
