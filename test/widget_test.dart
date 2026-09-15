// Smoke test: verifies the app boots to the splash screen without throwing.
// Supabase is not initialized in this test (no network/.env dependency) —
// full navigation/auth flows are covered by integration tests instead.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/auth/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders the app name and a progress indicator',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SplashScreen()),
      ),
    );

    expect(find.text('Communeo'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Advance past the entrance animation. Not pumpAndSettle() — the splash
    // screen's progress indicator spins indefinitely by design, so settling
    // would never complete.
    await tester.pump(const Duration(milliseconds: 900));
  });
}
