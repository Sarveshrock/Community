import '../entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> listProjects({int limit = 20, int offset = 0});
  Future<Project> getProject(String id);
  Future<Project> createProject(
      Map<String, dynamic> data, List<String> skillIds);

  Future<bool> hasExpressedInterest(String projectId, String profileId);
  Future<void> expressInterest(String projectId, String? message);
  Future<List<Map<String, dynamic>>> getInterestsForProject(String projectId);
  Future<void> respondToInterest(String interestId, {required bool accept});
}
