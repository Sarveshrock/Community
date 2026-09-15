import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/supabase_config.dart';
import '../../data/repositories/interview_practice_repository_impl.dart';
import '../../domain/entities/interview_practice.dart';
import '../../domain/repositories/interview_practice_repository.dart';

export '../../domain/entities/interview_practice.dart';

final interviewPracticeRepositoryProvider =
    Provider<InterviewPracticeRepository>((ref) {
  return InterviewPracticeRepositoryImpl(supabase);
});

final interviewPracticePoolProvider =
    FutureProvider<List<InterviewPracticeProfile>>((ref) {
  return ref.watch(interviewPracticeRepositoryProvider).listPool();
});

final myInterviewPracticeProfileProvider =
    FutureProvider<InterviewPracticeProfile?>((ref) {
  return ref.watch(interviewPracticeRepositoryProvider).myProfile();
});

final interviewPracticePartnerProvider =
    FutureProvider.family<InterviewPracticeProfile, String>((ref, id) {
  return ref.watch(interviewPracticeRepositoryProvider).getProfile(id);
});

final sentInterviewPracticeRequestsProvider =
    FutureProvider<List<InterviewPracticeRequest>>((ref) {
  return ref.watch(interviewPracticeRepositoryProvider).listSentRequests();
});

final receivedInterviewPracticeRequestsProvider =
    FutureProvider<List<InterviewPracticeRequest>>((ref) {
  return ref.watch(interviewPracticeRepositoryProvider).listReceivedRequests();
});

class InterviewPracticeController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> upsertMyProfile(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(interviewPracticeRepositoryProvider).upsertMyProfile(data));
    state = result;
    if (!result.hasError) {
      ref.invalidate(myInterviewPracticeProfileProvider);
      ref.invalidate(interviewPracticePoolProvider);
    }
    return !result.hasError;
  }

  Future<bool> requestPractice(String partnerId,
      {required String targetRole, String? message}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref
        .read(interviewPracticeRepositoryProvider)
        .requestPractice(partnerId, targetRole: targetRole, message: message));
    state = result;
    if (!result.hasError) {
      ref.invalidate(sentInterviewPracticeRequestsProvider);
      ref.read(analyticsServiceProvider).log(
          AnalyticsEvents.interviewPracticeRequested, {'partner_id': partnerId});
    }
    return !result.hasError;
  }

  Future<bool> respondToRequest(String requestId, {required bool accept}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref
        .read(interviewPracticeRepositoryProvider)
        .respondToRequest(requestId, accept: accept));
    state = result;
    if (!result.hasError) {
      ref.invalidate(receivedInterviewPracticeRequestsProvider);
    }
    return !result.hasError;
  }

  Future<bool> cancelRequest(String requestId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(interviewPracticeRepositoryProvider).cancelRequest(requestId));
    state = result;
    if (!result.hasError) {
      ref.invalidate(sentInterviewPracticeRequestsProvider);
      ref.invalidate(receivedInterviewPracticeRequestsProvider);
    }
    return !result.hasError;
  }

  Future<bool> markCompleted(String requestId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(interviewPracticeRepositoryProvider).markCompleted(requestId));
    state = result;
    if (!result.hasError) {
      ref.invalidate(sentInterviewPracticeRequestsProvider);
      ref.invalidate(receivedInterviewPracticeRequestsProvider);
    }
    return !result.hasError;
  }
}

final interviewPracticeControllerProvider =
    AsyncNotifierProvider<InterviewPracticeController, void>(
        InterviewPracticeController.new);
