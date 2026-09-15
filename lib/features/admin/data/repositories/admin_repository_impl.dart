import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../moderation/domain/report_target.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> isAdmin(String profileId) async {
    try {
      final data = await _client
          .from(Tables.userRoles)
          .select('role')
          .eq('profile_id', profileId)
          .inFilter('role', ['admin', 'moderator']);
      return (data as List).isNotEmpty;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<Report>> listReports(
      {ReportStatus? status, int limit = 50, int offset = 0}) async {
    try {
      var query = _client
          .from(Tables.reports)
          .select('*, profiles!reports_reporter_id_fkey(full_name)');
      if (status != null) query = query.eq('status', status.value);
      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => Report.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> updateReportStatus(String reportId, ReportStatus status) async {
    try {
      await _client
          .from(Tables.reports)
          .update({'status': status.value}).eq('id', reportId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> recordAction({
    String? reportId,
    required ReportTargetType targetType,
    required String targetId,
    required String action,
    String? notes,
  }) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.moderationActions).insert({
        'report_id': reportId,
        'moderator_id': myId,
        'target_type': targetType.value,
        'target_id': targetId,
        'action': action,
        'notes': notes,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<ModerationAction>> listActionsForTarget(
      ReportTargetType targetType, String targetId) async {
    try {
      final data = await _client
          .from(Tables.moderationActions)
          .select('*, profiles!moderation_actions_moderator_id_fkey(full_name)')
          .eq('target_type', targetType.value)
          .eq('target_id', targetId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => ModerationAction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
