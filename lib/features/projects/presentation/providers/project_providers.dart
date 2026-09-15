import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

export '../../domain/entities/project.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(supabase);
});

final projectsListProvider = FutureProvider<List<Project>>((ref) {
  return ref.watch(projectRepositoryProvider).listProjects();
});

final projectDetailProvider = FutureProvider.family<Project, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).getProject(id);
});

final hasExpressedInterestProvider =
    FutureProvider.family<bool, String>((ref, projectId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;
  return ref
      .watch(projectRepositoryProvider)
      .hasExpressedInterest(projectId, user.id);
});

final projectInterestsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projectId) {
  return ref.watch(projectRepositoryProvider).getInterestsForProject(projectId);
});

class ProjectController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createProject(
      Map<String, dynamic> data, List<String> skillIds) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(projectRepositoryProvider).createProject(data, skillIds));
    state = result;
    if (!result.hasError) ref.invalidate(projectsListProvider);
    return !result.hasError;
  }

  Future<bool> expressInterest(String projectId, String? message) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref
        .read(projectRepositoryProvider)
        .expressInterest(projectId, message));
    state = result;
    if (!result.hasError) {
      ref.invalidate(hasExpressedInterestProvider(projectId));
      ref
          .read(analyticsServiceProvider)
          .log(AnalyticsEvents.projectInterest, {'project_id': projectId});
    }
    return !result.hasError;
  }

  Future<bool> respondToInterest(String projectId, String interestId,
      {required bool accept}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(projectRepositoryProvider)
          .respondToInterest(interestId, accept: accept),
    );
    state = result;
    if (!result.hasError) ref.invalidate(projectInterestsProvider(projectId));
    return !result.hasError;
  }
}

final projectControllerProvider =
    AsyncNotifierProvider<ProjectController, void>(ProjectController.new);
