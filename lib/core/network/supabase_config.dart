import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bootstraps the Supabase client from public, client-safe env values only.
/// See spec section 76: SUPABASE_URL / SUPABASE_ANON_KEY are the only values
/// permitted here. Private secrets (AI keys, news API keys) must never be
/// referenced from Flutter — they live exclusively in Edge Function secrets.
class SupabaseConfig {
  SupabaseConfig._();

  static String get url {
    final value = dotenv.env['SUPABASE_URL'];
    if (value == null || value.isEmpty) {
      throw StateError(
        'SUPABASE_URL is missing. Copy .env.example to .env and fill in your project values.',
      );
    }
    return value;
  }

  static String get anonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY'];
    if (value == null || value.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY is missing. Copy .env.example to .env and fill in your project values.',
      );
    }
    return value;
  }

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: url,
      // supabase_flutter renamed anonKey -> publishableKey; it accepts the
      // same anon/public key value from the Supabase dashboard either way.
      publishableKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}

/// Convenience accessor mirroring `Supabase.instance.client`.
SupabaseClient get supabase => Supabase.instance.client;
