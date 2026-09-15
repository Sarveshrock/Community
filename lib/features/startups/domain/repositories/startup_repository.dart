import '../entities/startup.dart';

abstract class StartupRepository {
  Future<List<Startup>> listStartups();
  Future<Startup> getStartup(String id);
  Future<List<StartupOpportunity>> getOpportunities(String startupId);
  Future<List<StartupOpportunity>> listAllOpenOpportunities();
  Future<Startup> createStartup(Map<String, dynamic> data);
  Future<void> createOpportunity(String startupId, Map<String, dynamic> data);
}
