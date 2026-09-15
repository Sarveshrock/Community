import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/search_results.dart';
import '../../domain/repositories/search_repository.dart';

/// Unified search across People / Jobs / Projects / Hackathons / Startups /
/// Mentors / Communities (spec section 68), fanning a single query out to
/// each table in parallel. Debouncing is handled in the UI layer. News is
/// intentionally excluded — it's fetched live from an external API with no
/// per-keystroke search endpoint, not stored in Supabase.
class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<SearchResults> search(String query) async {
    try {
      final myId = _client.auth.currentUser?.id;
      final like = '%$query%';

      final peopleQuery = _client
          .from(Tables.profiles)
          .select('id, full_name, current_role, avatar_url')
          .eq('professional_discoverable', true)
          .or('full_name.ilike.$like,current_role.ilike.$like,current_company.ilike.$like')
          .limit(10);

      final jobsQuery = _client
          .from(Tables.jobs)
          .select('id, title, company_name')
          .eq('status', 'open')
          .or('title.ilike.$like,company_name.ilike.$like')
          .limit(10);

      final projectsQuery = _client
          .from(Tables.projects)
          .select('id, title, category')
          .eq('status', 'open')
          .ilike('title', like)
          .limit(10);

      final hackathonsQuery = _client
          .from(Tables.hackathons)
          .select('id, name')
          .ilike('name', like)
          .limit(10);

      final startupsQuery = _client
          .from(Tables.startups)
          .select('id, name, industry')
          .or('name.ilike.$like,industry.ilike.$like')
          .limit(10);

      final mentorsQuery = _client
          .from(Tables.mentorProfiles)
          .select('profile_id, bio, profiles(full_name)')
          .eq('available', true)
          .ilike('bio', like)
          .limit(10);

      final communitiesQuery = _client
          .from(Tables.communities)
          .select('id, name, description')
          .or('name.ilike.$like,description.ilike.$like')
          .limit(10);

      final results = await Future.wait([
        peopleQuery,
        jobsQuery,
        projectsQuery,
        hackathonsQuery,
        startupsQuery,
        mentorsQuery,
        communitiesQuery,
      ]);

      final people = (results[0] as List)
          .cast<Map<String, dynamic>>()
          .where((p) => p['id'] != myId)
          .toList();

      return SearchResults(
        people: people,
        jobs: (results[1] as List).cast<Map<String, dynamic>>(),
        projects: (results[2] as List).cast<Map<String, dynamic>>(),
        hackathons: (results[3] as List).cast<Map<String, dynamic>>(),
        startups: (results[4] as List).cast<Map<String, dynamic>>(),
        mentors: (results[5] as List).cast<Map<String, dynamic>>(),
        communities: (results[6] as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
