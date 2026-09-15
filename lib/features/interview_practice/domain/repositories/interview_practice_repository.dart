import '../entities/interview_practice.dart';

abstract class InterviewPracticeRepository {
  Future<List<InterviewPracticeProfile>> listPool({int limit = 20, int offset = 0});
  Future<InterviewPracticeProfile?> myProfile();
  Future<InterviewPracticeProfile> getProfile(String profileId);
  Future<void> upsertMyProfile(Map<String, dynamic> data);

  Future<List<InterviewPracticeRequest>> listSentRequests();
  Future<List<InterviewPracticeRequest>> listReceivedRequests();

  Future<String> requestPractice(String partnerId,
      {required String targetRole, String? message});
  Future<void> respondToRequest(String requestId, {required bool accept});
  Future<void> cancelRequest(String requestId);
  Future<void> markCompleted(String requestId);
}
