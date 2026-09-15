import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../posts/presentation/providers/post_providers.dart';

/// Lightweight preview queries for the personalized Home dashboard (spec
/// section 59). These intentionally stay separate from each feature's own
/// full list providers — a home preview only ever needs a handful of rows.
final homeHackathonsPreviewProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('hackathons')
      .select('id, name, event_date')
      .order('created_at', ascending: false)
      .limit(5);
  return (data as List).cast<Map<String, dynamic>>();
});

final homeJobsPreviewProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('jobs')
      .select('id, title, company_name, work_mode')
      .eq('status', 'open')
      .order('created_at', ascending: false)
      .limit(5);
  return (data as List).cast<Map<String, dynamic>>();
});

final homeProjectsPreviewProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('projects')
      .select('id, title, category, collaboration_type')
      .eq('status', 'open')
      .order('created_at', ascending: false)
      .limit(5);
  return (data as List).cast<Map<String, dynamic>>();
});

/// Reuses the Posts feature's own repository (rather than a raw query, like
/// the previews above) — a post preview needs the full entity (media,
/// links, mentions, author) for `PostCard`, not a lightweight row.
final homePostsPreviewProvider = FutureProvider<List<Post>>((ref) {
  return ref.watch(postRepositoryProvider).listFeed(limit: 3);
});

/// Community-wide totals for the Home stats row. Read-only `count` queries
/// against tables that already exist — no schema, RLS or business-logic
/// changes — so the numbers shown are the real (RLS-visible) row counts
/// rather than invented marketing figures.
typedef CommunityStats = ({
  int people,
  int projects,
  int opportunities,
  int communities,
});

final communityStatsProvider = FutureProvider<CommunityStats>((ref) async {
  Future<int> countOf(String table) async {
    try {
      return await supabase.from(table).count(CountOption.exact);
    } catch (_) {
      // A stat that can't be read shouldn't take the whole row down.
      return 0;
    }
  }

  final counts = await Future.wait([
    countOf(Tables.profiles),
    countOf(Tables.projects),
    countOf(Tables.jobs),
    countOf(Tables.communities),
  ]);

  return (
    people: counts[0],
    projects: counts[1],
    opportunities: counts[2],
    communities: counts[3],
  );
});

final pendingConnectionRequestsCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return 0;
  final data = await supabase
      .from('connections')
      .select('id')
      .eq('receiver_id', user.id)
      .eq('status', 'pending');
  return (data as List).length;
});

/// Derived from the same realtime notifications stream the Notifications
/// screen uses, so the home badge updates live too instead of only on
/// next load (spec section 7).
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications =
      ref.watch(myNotificationsProvider).valueOrNull ?? const [];
  return notifications.where((n) => !n.isRead).length;
});
