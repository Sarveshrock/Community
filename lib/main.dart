import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  // Top-level hardening: an uncaught error (framework or async) must never
  // surface as a blank/grey screen mid-demo. Every error still logs to the
  // console (there's no crash-reporting service wired up — see the
  // project's own known-limitations notes — so this is the only visibility
  // into a failure short of a connected debugger).
  ErrorWidget.builder = (details) => const _RecoverableErrorScreen();

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    await SupabaseConfig.initialize();
    runApp(const ProviderScope(child: CommuneoApp()));
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

class CommuneoApp extends ConsumerWidget {
  const CommuneoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Communeo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

/// Replaces Flutter's default error widget (a debug-only red screen, a
/// blank grey box in release) so a single widget failing to build anywhere
/// in the tree — never something worth ending a live demo over — shows a
/// calm, on-brand message instead. Deliberately has no navigation of its
/// own: a build-time error widget can't assume a Navigator/GoRouter context
/// is available above it.
class _RecoverableErrorScreen extends StatelessWidget {
  const _RecoverableErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF070912),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, color: Colors.white54, size: 32),
              SizedBox(height: 12),
              Text(
                'Something didn\'t load right.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
