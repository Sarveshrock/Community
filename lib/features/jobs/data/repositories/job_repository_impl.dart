import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_applicant.dart';
import '../../domain/entities/job_application_question.dart';
import '../../domain/repositories/job_repository.dart';

class JobRepositoryImpl implements JobRepository {
  JobRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, job_required_skills(skills(name)), job_preferred_skills(skills(name))';

  @override
  Future<List<Job>> listJobs({JobFilters filters = const JobFilters(), int limit = 20, int offset = 0}) async {
    try {
      var query = _client.from(Tables.jobs).select(_select).eq('status', 'open');
      if (filters.category != null) query = query.eq('job_category', filters.category!);
      if (filters.employmentType != null) query = query.eq('employment_type', filters.employmentType!);
      if (filters.workMode != null) query = query.eq('work_mode', filters.workMode!);
      if (filters.query != null && filters.query!.isNotEmpty) {
        query = query.or('title.ilike.%${filters.query}%,company_name.ilike.%${filters.query}%');
      }
      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => Job.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Job> getJob(String id) async {
    try {
      final data =
          await _client.from(Tables.jobs).select(_select).eq('id', id).single();
      return Job.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Job> createJob(
    Map<String, dynamic> data, {
    List<String> requiredSkillIds = const [],
    List<String> preferredSkillIds = const [],
    List<JobApplicationQuestion> questions = const [],
  }) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client
          .from(Tables.jobs)
          .insert({...data, 'poster_id': myId})
          .select()
          .single();
      final jobId = inserted['id'] as String;
      if (requiredSkillIds.isNotEmpty) {
        await _client.from(Tables.jobRequiredSkills).insert([
          for (final skillId in requiredSkillIds) {'job_id': jobId, 'skill_id': skillId},
        ]);
      }
      if (preferredSkillIds.isNotEmpty) {
        await _client.from(Tables.jobPreferredSkills).insert([
          for (final skillId in preferredSkillIds) {'job_id': jobId, 'skill_id': skillId},
        ]);
      }
      if (questions.isNotEmpty) {
        await _client
            .from(Tables.jobApplicationQuestions)
            .insert([for (final q in questions) q.toInsertJson(jobId)]);
      }
      return await getJob(jobId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> updateJob(
    String id,
    Map<String, dynamic> changes, {
    List<String>? requiredSkillIds,
    List<String>? preferredSkillIds,
    List<JobApplicationQuestion>? questions,
  }) async {
    try {
      if (changes.isNotEmpty) {
        await _client.from(Tables.jobs).update(changes).eq('id', id);
      }
      if (requiredSkillIds != null) {
        await _client.from(Tables.jobRequiredSkills).delete().eq('job_id', id);
        if (requiredSkillIds.isNotEmpty) {
          await _client
              .from(Tables.jobRequiredSkills)
              .insert([for (final skillId in requiredSkillIds) {'job_id': id, 'skill_id': skillId}]);
        }
      }
      if (preferredSkillIds != null) {
        await _client.from(Tables.jobPreferredSkills).delete().eq('job_id', id);
        if (preferredSkillIds.isNotEmpty) {
          await _client
              .from(Tables.jobPreferredSkills)
              .insert([for (final skillId in preferredSkillIds) {'job_id': id, 'skill_id': skillId}]);
        }
      }
      if (questions != null) {
        await _client.from(Tables.jobApplicationQuestions).delete().eq('job_id', id);
        if (questions.isNotEmpty) {
          await _client
              .from(Tables.jobApplicationQuestions)
              .insert([for (final q in questions) q.toInsertJson(id)]);
        }
      }
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> closeJob(String id) async {
    try {
      await _client.from(Tables.jobs).update({'status': 'closed'}).eq('id', id);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> reopenJob(String id) async {
    try {
      await _client.from(Tables.jobs).update({'status': 'open'}).eq('id', id);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> deleteJob(String id) async {
    try {
      await _client.from(Tables.jobs).delete().eq('id', id);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> uploadCompanyLogo(String jobId, List<int> bytes, String fileExt) async {
    try {
      final path = 'jobs/$jobId/logo.$fileExt';
      await _client.storage.from(StorageBuckets.communityMedia).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from(StorageBuckets.communityMedia).getPublicUrl(path);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> uploadApplicationFile(
    String profileId,
    String jobId,
    List<int> bytes,
    String fileExt, {
    required String kind,
  }) async {
    try {
      final path = '$profileId/$jobId/$kind.$fileExt';
      await _client.storage.from(StorageBuckets.resumes).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: true),
          );
      return path;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> getResumeSignedUrl(String path) async {
    try {
      return await _client.storage.from(StorageBuckets.resumes).createSignedUrl(path, 300);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<JobApplicationQuestion>> listApplicationQuestions(String jobId) async {
    try {
      final data = await _client
          .from(Tables.jobApplicationQuestions)
          .select()
          .eq('job_id', jobId)
          .order('sort_order');
      return (data as List)
          .map((e) => JobApplicationQuestion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<bool> hasApplied(String jobId, String profileId) async {
    try {
      final data = await _client
          .from(Tables.jobApplications)
          .select('id')
          .eq('job_id', jobId)
          .eq('profile_id', profileId)
          .maybeSingle();
      return data != null;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> apply(
    String jobId, {
    String? coverMessage,
    String? resumePath,
    String? portfolioPath,
    String? githubUrl,
    String? linkedinUrl,
    Map<String, String> questionAnswers = const {},
  }) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client
          .from(Tables.jobApplications)
          .insert({
            'job_id': jobId,
            'profile_id': myId,
            'cover_message': coverMessage,
            'resume_path': resumePath,
            'portfolio_path': portfolioPath,
            'github_url': githubUrl,
            'linkedin_url': linkedinUrl,
          })
          .select('id')
          .single();
      final applicationId = inserted['id'] as String;
      if (questionAnswers.isNotEmpty) {
        await _client.from(Tables.jobApplicationAnswers).insert([
          for (final entry in questionAnswers.entries)
            {'application_id': applicationId, 'question_id': entry.key, 'answer_text': entry.value},
        ]);
      }
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<JobApplicant>> getApplicationsForJob(String jobId) async {
    try {
      final data = await _client
          .from(Tables.jobApplications)
          .select('*, profiles(full_name, avatar_url, current_role)')
          .eq('job_id', jobId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => JobApplicant.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> updateApplicationStatus(
      String applicationId, String status) async {
    try {
      await _client
          .from(Tables.jobApplications)
          .update({'status': status}).eq('id', applicationId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
