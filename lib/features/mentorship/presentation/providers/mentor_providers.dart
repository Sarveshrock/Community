import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/mentor_repository_impl.dart';
import '../../domain/entities/mentor.dart';
import '../../domain/repositories/mentor_repository.dart';

export '../../domain/entities/mentor.dart';

final mentorRepositoryProvider =
    Provider<MentorRepository>((ref) => MentorRepositoryImpl(supabase));

final mentorsListProvider = FutureProvider<List<Mentor>>((ref) {
  return ref.watch(mentorRepositoryProvider).listMentors();
});

final mentorDetailProvider = FutureProvider.family<Mentor, String>((ref, id) {
  return ref.watch(mentorRepositoryProvider).getMentor(id);
});

/// The signed-in user's own mentor profile, or null if they haven't
/// created one yet — drives Profile's "Become a Mentor" vs "Mentor
/// Profile" entry point.
final myMentorProfileProvider = FutureProvider<Mentor?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(mentorRepositoryProvider).getMyMentorProfile(user.id);
});

class MentorController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> requestMentorship(String mentorId,
      {String? topic, String? message}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(mentorRepositoryProvider)
          .requestMentorship(mentorId, topic, message),
    );
    state = result;
    if (!result.hasError) {
      ref
          .read(analyticsServiceProvider)
          .log(AnalyticsEvents.mentorRequest, {'mentor_id': mentorId});
    }
    return !result.hasError;
  }

  Future<bool> becomeMentor(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(mentorRepositoryProvider).becomeMentor(data));
    state = result;
    if (!result.hasError) {
      ref.invalidate(mentorsListProvider);
      ref.invalidate(myMentorProfileProvider);
      final myId = ref.read(authStateProvider).valueOrNull?.id;
      if (myId != null) ref.invalidate(mentorDetailProvider(myId));
    }
    return !result.hasError;
  }
}

final mentorControllerProvider =
    AsyncNotifierProvider<MentorController, void>(MentorController.new);
