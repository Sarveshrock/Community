/// Unified search results across the app (spec section 68): People, Jobs,
/// Projects, Hackathons, Startups, Mentors, Communities. News is excluded —
/// it's fetched live from an external API, not stored in Supabase.
class SearchResults {
  const SearchResults({
    this.people = const [],
    this.jobs = const [],
    this.projects = const [],
    this.hackathons = const [],
    this.startups = const [],
    this.mentors = const [],
    this.communities = const [],
  });

  final List<Map<String, dynamic>> people;
  final List<Map<String, dynamic>> jobs;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> hackathons;
  final List<Map<String, dynamic>> startups;
  final List<Map<String, dynamic>> mentors;
  final List<Map<String, dynamic>> communities;

  bool get isEmpty =>
      people.isEmpty &&
      jobs.isEmpty &&
      projects.isEmpty &&
      hackathons.isEmpty &&
      startups.isEmpty &&
      mentors.isEmpty &&
      communities.isEmpty;
}
