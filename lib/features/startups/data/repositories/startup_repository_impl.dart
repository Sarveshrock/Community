import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/startup.dart';
import '../../domain/repositories/startup_repository.dart';

class StartupRepositoryImpl implements StartupRepository {
  StartupRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Startup>> listStartups() async {
    try {
      final data = await _client
          .from(Tables.startups)
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return (data as List)
          .map((e) => Startup.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Startup> getStartup(String id) async {
    try {
      final data =
          await _client.from(Tables.startups).select().eq('id', id).single();
      return Startup.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<StartupOpportunity>> getOpportunities(String startupId) async {
    try {
      final data = await _client
          .from(Tables.startupOpportunities)
          .select()
          .eq('startup_id', startupId)
          .eq('status', 'open');
      return (data as List)
          .map((e) => StartupOpportunity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<StartupOpportunity>> listAllOpenOpportunities() async {
    try {
      final data = await _client
          .from(Tables.startupOpportunities)
          .select('*, startups(name)')
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(50);
      return (data as List)
          .map((e) => StartupOpportunity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<Startup> createStartup(Map<String, dynamic> data) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client
          .from(Tables.startups)
          .insert({...data, 'owner_id': myId})
          .select()
          .single();
      await _client.from(Tables.startupMembers).insert({
        'startup_id': inserted['id'],
        'profile_id': myId,
        'role': 'Founder',
        'is_founder': true,
      });
      return Startup.fromJson(inserted);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> createOpportunity(
      String startupId, Map<String, dynamic> data) async {
    try {
      await _client
          .from(Tables.startupOpportunities)
          .insert({...data, 'startup_id': startupId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
