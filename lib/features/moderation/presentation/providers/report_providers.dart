import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_config.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../domain/report_target.dart';
import '../../domain/repositories/report_repository.dart';

export '../../domain/report_target.dart';

final reportRepositoryProvider =
    Provider<ReportRepository>((ref) => ReportRepositoryImpl(supabase));

class ReportController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportCategory category,
    String? details,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(reportRepositoryProvider).submitReport(
            targetType: targetType,
            targetId: targetId,
            category: category,
            details: details,
          ),
    );
    state = result;
    return !result.hasError;
  }
}

final reportControllerProvider =
    AsyncNotifierProvider<ReportController, void>(ReportController.new);
