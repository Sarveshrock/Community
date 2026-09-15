import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams whether the device currently has any network connectivity.
/// Screens use this to show an offline banner and gate retries (spec
/// section 70) rather than letting requests fail silently.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));
});
