import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/job_repository_impl.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_applicant.dart';
import '../../domain/entities/job_application_question.dart';
import '../../domain/repositories/job_repository.dart';

export '../../domain/entities/job.dart';
export '../../domain/entities/job_applicant.dart';
export '../../domain/entities/job_application_question.dart';
export '../../domain/job_action_state.dart';
export '../../domain/repositories/job_repository.dart' show JobFilters;

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepositoryImpl(supabase);
});

final jobFiltersProvider = StateProvider<JobFilters>((ref) => const JobFilters());

final jobsListProvider = FutureProvider<List<Job>>((ref) {
  final filters = ref.watch(jobFiltersProvider);
  return ref.watch(jobRepositoryProvider).listJobs(filters: filters);
});

final jobDetailProvider = FutureProvider.family<Job, String>((ref, id) {
  return ref.watch(jobRepositoryProvider).getJob(id);
});

final jobApplicationQuestionsProvider =
    FutureProvider.family<List<JobApplicationQuestion>, String>((ref, jobId) {
  return ref.watch(jobRepositoryProvider).listApplicationQuestions(jobId);
});

final hasAppliedProvider =
    FutureProvider.family<bool, String>((ref, jobId) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;
  return ref.watch(jobRepositoryProvider).hasApplied(jobId, user.id);
});

final jobApplicationsProvider =
    FutureProvider.family<List<JobApplicant>, String>((ref, jobId) {
  return ref.watch(jobRepositoryProvider).getApplicationsForJob(jobId);
});

class JobController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Job?> createJob(
    Map<String, dynamic> data, {
    List<String> requiredSkillIds = const [],
    List<String> preferredSkillIds = const [],
    List<JobApplicationQuestion> questions = const [],
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(jobRepositoryProvider).createJob(
            data,
            requiredSkillIds: requiredSkillIds,
            preferredSkillIds: preferredSkillIds,
            questions: questions,
          ),
    );
    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    if (!result.hasError) ref.invalidate(jobsListProvider);
    return result.valueOrNull;
  }

  Future<bool> updateJob(
    String id,
    Map<String, dynamic> changes, {
    List<String>? requiredSkillIds,
    List<String>? preferredSkillIds,
    List<JobApplicationQuestion>? questions,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(jobRepositoryProvider).updateJob(
          id,
          changes,
          requiredSkillIds: requiredSkillIds,
          preferredSkillIds: preferredSkillIds,
          questions: questions,
        ));
    state = result;
    if (!result.hasError) {
      ref.invalidate(jobDetailProvider(id));
      ref.invalidate(jobsListProvider);
    }
    return !result.hasError;
  }

  Future<bool> closeJob(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(jobRepositoryProvider).closeJob(id));
    state = result;
    if (!result.hasError) {
      ref.invalidate(jobDetailProvider(id));
      ref.invalidate(jobsListProvider);
    }
    return !result.hasError;
  }

  Future<bool> reopenJob(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(jobRepositoryProvider).reopenJob(id));
    state = result;
    if (!result.hasError) {
      ref.invalidate(jobDetailProvider(id));
      ref.invalidate(jobsListProvider);
    }
    return !result.hasError;
  }

  Future<bool> deleteJob(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(jobRepositoryProvider).deleteJob(id));
    state = result;
    if (!result.hasError) ref.invalidate(jobsListProvider);
    return !result.hasError;
  }

  Future<String?> uploadCompanyLogo(String jobId, List<int> bytes, String fileExt) async {
    try {
      return await ref.read(jobRepositoryProvider).uploadCompanyLogo(jobId, bytes, fileExt);
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadApplicationFile(
    String profileId,
    String jobId,
    List<int> bytes,
    String fileExt, {
    required String kind,
  }) async {
    try {
      return await ref
          .read(jobRepositoryProvider)
          .uploadApplicationFile(profileId, jobId, bytes, fileExt, kind: kind);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getResumeSignedUrl(String path) async {
    try {
      return await ref.read(jobRepositoryProvider).getResumeSignedUrl(path);
    } catch (_) {
      return null;
    }
  }

  Future<bool> apply(
    String jobId, {
    String? coverMessage,
    String? resumePath,
    String? portfolioPath,
    String? githubUrl,
    String? linkedinUrl,
    Map<String, String> questionAnswers = const {},
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(jobRepositoryProvider).apply(
            jobId,
            coverMessage: coverMessage,
            resumePath: resumePath,
            portfolioPath: portfolioPath,
            githubUrl: githubUrl,
            linkedinUrl: linkedinUrl,
            questionAnswers: questionAnswers,
          ),
    );
    state = result;
    if (!result.hasError) {
      ref.invalidate(hasAppliedProvider(jobId));
      ref
          .read(analyticsServiceProvider)
          .log(AnalyticsEvents.jobApplication, {'job_id': jobId});
    }
    return !result.hasError;
  }

  Future<bool> updateApplicationStatus(
      String jobId, String applicationId, String status) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(jobRepositoryProvider)
          .updateApplicationStatus(applicationId, status),
    );
    state = result;
    if (!result.hasError) ref.invalidate(jobApplicationsProvider(jobId));
    return !result.hasError;
  }
}

final jobControllerProvider =
    AsyncNotifierProvider<JobController, void>(JobController.new);
