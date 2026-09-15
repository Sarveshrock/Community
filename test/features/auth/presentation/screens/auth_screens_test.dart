// Renders the redesigned Sign In / Create Account screens at every phone
// size the redesign spec called out. As with `home_screen_test.dart`, the
// real payoff is `tester.takeException()` — a RenderFlex overflow on the
// narrowest supported screen surfaces here instead of on a device.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:community_app/features/auth/presentation/screens/sign_up_screen.dart';

const _phoneSizes = <String, Size>{
  'very small phone (320x568)': Size(320, 568),
  'small Android (360x800)': Size(360, 800),
  'iPhone SE-ish (375x812)': Size(375, 812),
  'iPhone 12/13 (390x844)': Size(390, 844),
  'large phone (414x896)': Size(414, 896),
  'large phone (430x932)': Size(430, 932),
};

Widget _harness(Widget child) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => child),
    GoRoute(path: '/sign-up', builder: (_, __) => const SignUpScreen()),
    GoRoute(path: '/forgot-password', builder: (_, __) => const Scaffold()),
  ]);
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  for (final entry in _phoneSizes.entries) {
    testWidgets('Sign in lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(const SignInScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('back!'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Create account lays out with no overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(const SignUpScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Create your'), findsOneWidget);
      expect(find.text('account'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    });
  }

  testWidgets('Sign in has no Full Name field and links to Create account', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(const SignInScreen()));
    await tester.pump();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.textContaining('Full name'), findsNothing);
    expect(find.textContaining('Full Name'), findsNothing);

    final createAccountLink = find.textContaining('Create an account', findRichText: true);
    await tester.ensureVisible(createAccountLink);
    await tester.pumpAndSettle();
    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    expect(find.byType(SignUpScreen), findsOneWidget);
  });

  testWidgets('Create account has exactly Email/Password/Confirm password, no Full Name',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Starts from Sign In and pushes to Sign Up (mirroring the app's real
    // route graph — `/sign-up` is only ever reached by a push from
    // `/sign-in`) so the footer's `context.pop()` back to Sign In has a
    // real route to return to, exactly as it would on device.
    await tester.pumpWidget(_harness(const SignInScreen()));
    await tester.pump();
    await tester.tap(find.textContaining('Create an account', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.textContaining('Full name'), findsNothing);
    expect(find.textContaining('Full Name'), findsNothing);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);

    final signInLink = find.textContaining('Sign in', findRichText: true);
    await tester.ensureVisible(signInLink);
    await tester.pumpAndSettle();
    await tester.tap(signInLink);
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
  });
}
