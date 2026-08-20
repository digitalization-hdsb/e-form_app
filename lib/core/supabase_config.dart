import 'package:supabase_flutter/supabase_flutter.dart';

/// Credentials are injected at build/run time so they never live in source
/// control, e.g.:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// These must point at the SAME Supabase project the HDSB e-Form website
/// uses (see src/supabase.ts and the website's .env), so the Flutter app
/// reads/writes the exact same tables, auth users, and storage buckets.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<void> init() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}

SupabaseClient get supabase => Supabase.instance.client;
