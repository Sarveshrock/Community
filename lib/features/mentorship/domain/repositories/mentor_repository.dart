import '../entities/mentor.dart';

abstract class MentorRepository {
  Future<List<Mentor>> listMentors();
  Future<Mentor> getMentor(String profileId);

  /// Null if the caller doesn't have a mentor profile yet — used to decide
  /// whether Profile shows "Become a Mentor" or "Mentor Profile".
  Future<Mentor?> getMyMentorProfile(String profileId);

  Future<void> requestMentorship(
      String mentorId, String? topic, String? message);

  /// Creates the caller's mentor profile, or partially updates it if one
  /// already exists (upsert on `profile_id`) — the same call also powers
  /// Edit and Pause/Resume (a partial `{'available': false}` payload only
  /// touches that column, leaving everything else intact).
  Future<void> becomeMentor(Map<String, dynamic> data);
}
