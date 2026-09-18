import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_config.dart';
import '../../data/repositories/startup_repository_impl.dart';
import '../../domain/entities/startup.dart';
import '../../domain/repositories/startup_repository.dart';

final startupRepositoryProvider =
    Provider<StartupRepository>((ref) => StartupRepositoryImpl(supabase));

final startupsListProvider = FutureProvider<List<Startup>>((ref) {
  return ref.watch(startupRepositoryProvider).listStartups();
});

final startupDetailProvider = FutureProvider.family<Startup, String>((ref, id) {
  return ref.watch(startupRepositoryProvider).getStartup(id);
});

final startupOpportunitiesProvider =
    FutureProvider.family<List<StartupOpportunity>, String>((ref, startupId) {
  return ref.watch(startupRepositoryProvider).getOpportunities(startupId);
});

class StartupController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createStartup(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(startupRepositoryProvider).createStartup(data));
    state = result;
    if (!result.hasError) ref.invalidate(startupsListProvider);
    return !result.hasError;
  }

  Future<bool> createOpportunity(
      String startupId, Map<String, dynamic> data) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(startupRepositoryProvider).createOpportunity(startupId, data));
    state = result;
    if (!result.hasError) {
      ref.invalidate(startupOpportunitiesProvider(startupId));
    }
    return !result.hasError;
  }
}

final startupControllerProvider =
    AsyncNotifierProvider<StartupController, void>(StartupController.new);
