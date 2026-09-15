import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../moderation/domain/report_target.dart';
import '../../data/repositories/admin_repository_impl.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/admin_repository.dart';

export '../../domain/entities/report.dart';

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepositoryImpl(supabase));

/// UI-only gate for showing admin entry points. The actual authorization is
/// always enforced server-side by RLS (spec section 73) — this just avoids
/// showing moderation affordances to users who can't use them.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;
  return ref.watch(adminRepositoryProvider).isAdmin(user.id);
});

final reportsQueueProvider =
    FutureProvider.family<List<Report>, ReportStatus?>((ref, status) {
  return ref.watch(adminRepositoryProvider).listReports(status: status);
});

class AdminController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> resolveReport(
    String reportId, {
    required ReportStatus status,
    required ReportTargetType targetType,
    required String targetId,
    required String action,
    String? notes,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateReportStatus(reportId, status);
      await repo.recordAction(
        reportId: reportId,
        targetType: targetType,
        targetId: targetId,
        action: action,
        notes: notes,
      );
    });
    state = result;
    if (!result.hasError) {
      ref.invalidate(reportsQueueProvider);
    }
    return !result.hasError;
  }
}

final adminControllerProvider =
    AsyncNotifierProvider<AdminController, void>(AdminController.new);
