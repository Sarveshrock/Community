import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/report_target.dart';
import '../../domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<void> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportCategory category,
    String? details,
  }) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.reports).insert({
        'reporter_id': myId,
        'target_type': targetType.value,
        'target_id': targetId,
        'category': category.value,
        'details': details,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
