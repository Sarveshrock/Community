import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../network/supabase_config.dart';

/// Logs privacy-conscious product analytics events (spec section 75) to the
/// `analytics_events` table. Fire-and-forget by design — a failed analytics
/// write must never block or surface an error for the user-facing action it
/// is attached to.
class AnalyticsService {
  AnalyticsService(this._client);

  final SupabaseClient _client;

  Future<void> log(String eventType,
      [Map<String, dynamic> data = const {}]) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;
    try {
      await _client.from(Tables.analyticsEvents).insert({
        'profile_id': myId,
        'event_type': eventType,
        'data': data,
      });
    } catch (e, st) {
      // Never let analytics failures affect the primary user action.
      debugPrint('AnalyticsService.log($eventType) failed: $e\n$st');
    }
  }
}

final analyticsServiceProvider =
    Provider<AnalyticsService>((ref) => AnalyticsService(supabase));
