import '../entities/job.dart';
import '../entities/job_applicant.dart';
import '../entities/job_application_question.dart';

class JobFilters {
  const JobFilters({this.query, this.category, this.employmentType, this.workMode});

  final String? query;
  final String? category;
  final String? employmentType;
  final String? workMode;

  bool get isEmpty => query == null && category == null && employmentType == null && workMode == null;

  JobFilters copyWith({
    String? query,
    Object? category = _unset,
    Object? employmentType = _unset,
    Object? workMode = _unset,
  }) {
    return JobFilters(
      query: query ?? this.query,
      category: identical(category, _unset) ? this.category : category as String?,
      employmentType: identical(employmentType, _unset) ? this.employmentType : employmentType as String?,
      workMode: identical(workMode, _unset) ? this.workMode : workMode as String?,
    );
  }
}

const _unset = Object();

abstract class JobRepository {
  Future<List<Job>> listJobs({JobFilters filters = const JobFilters(), int limit = 20, int offset = 0});
  Future<Job> getJob(String id);

  Future<Job> createJob(
    Map<String, dynamic> data, {
    List<String> requiredSkillIds = const [],
    List<String> preferredSkillIds = const [],
    List<JobApplicationQuestion> questions = const [],
  });

  Future<void> updateJob(
    String id,
    Map<String, dynamic> changes, {
    List<String>? requiredSkillIds,
    List<String>? preferredSkillIds,
    List<JobApplicationQuestion>? questions,
  });

  Future<void> closeJob(String id);
  Future<void> reopenJob(String id);
  Future<void> deleteJob(String id);

  Future<String> uploadCompanyLogo(String jobId, List<int> bytes, String fileExt);

  /// Uploads a resume/portfolio file to the private `resumes` bucket under
  /// the caller's own folder — returns the storage path (never a public
  /// URL; the bucket isn't public).
  Future<String> uploadApplicationFile(
    String profileId,
    String jobId,
    List<int> bytes,
    String fileExt, {
    required String kind,
  });

  /// A short-lived signed URL for viewing one resume/portfolio file — never
  /// a permanent public link, since the bucket is private applicant data.
  Future<String> getResumeSignedUrl(String path);

  Future<List<JobApplicationQuestion>> listApplicationQuestions(String jobId);

  Future<bool> hasApplied(String jobId, String profileId);

  Future<void> apply(
    String jobId, {
    String? coverMessage,
    String? resumePath,
    String? portfolioPath,
    String? githubUrl,
    String? linkedinUrl,
    Map<String, String> questionAnswers = const {},
  });

  Future<List<JobApplicant>> getApplicationsForJob(String jobId);
  Future<void> updateApplicationStatus(String applicationId, String status);
}
