// Renders the redesigned Forgot Password screen (now matching Sign In/Sign
// Up's AuthStyle premium dark brand moment instead of stock Material) at
// every phone size this session's redesigns test at, and locks down that
// the existing sendPasswordReset flow is unchanged — a visual-only restyle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:community_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:community_app/features/auth/presentation/screens/forgot_password_screen.dart';

class _RecordingAuthRepository implements AuthRepository {
  final List<String> resetCalls = [];
  bool shouldSucceed = true;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetCalls.add(email);
    if (!shouldSucceed) throw Exception('failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(_RecordingAuthRepository repo) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(path: '/sign-in', builder: (_, __) => const Scaffold(body: Text('Sign In'))),
  ]);
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  const phoneSizes = <String, Size>{
    'very small phone (320x568)': Size(320, 568),
    'small Android (360x800)': Size(360, 800),
    'iPhone SE-ish (375x812)': Size(375, 812),
    'iPhone 12/13 (390x844)': Size(390, 844),
    'large phone (414x896)': Size(414, 896),
    'large phone (430x932)': Size(430, 932),
  };

  for (final entry in phoneSizes.entries) {
    testWidgets('Forgot Password lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(_RecordingAuthRepository()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Send reset link'), findsOneWidget);
    });
  }

  testWidgets('submitting a valid email calls sendPasswordResetEmail and shows confirmation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _RecordingAuthRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), 'priya@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(repo.resetCalls, ['priya@example.com']);
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('an invalid email is rejected before calling the repository', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _RecordingAuthRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();

    expect(repo.resetCalls, isEmpty);
  });
}
