import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/mentor.dart';
import '../../domain/repositories/mentor_repository.dart';

class MentorRepositoryImpl implements MentorRepository {
  MentorRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Mentor>> listMentors() async {
    try {
      final data = await _client
          .from(Tables.mentorProfiles)
          .select('*, profiles(full_name, avatar_url, current_role)')
          .eq('available', true);
      return (data as List)
          .map((e) => Mentor.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Mentor> getMentor(String profileId) async {
    try {
      final data = await _client
          .from(Tables.mentorProfiles)
          .select('*, profiles(full_name, avatar_url, current_role)')
          .eq('profile_id', profileId)
          .single();
      return Mentor.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Mentor?> getMyMentorProfile(String profileId) async {
    try {
      final data = await _client
          .from(Tables.mentorProfiles)
          .select('*, profiles(full_name, avatar_url, current_role)')
          .eq('profile_id', profileId)
          .maybeSingle();
      return data == null ? null : Mentor.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> requestMentorship(
      String mentorId, String? topic, String? message) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.mentorRequests).insert({
        'mentor_id': mentorId,
        'requester_id': myId,
        'topic': topic,
        'message': message,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> becomeMentor(Map<String, dynamic> data) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client
          .from(Tables.mentorProfiles)
          .upsert({'profile_id': myId, ...data});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
