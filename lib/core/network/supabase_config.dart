import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración segura de Supabase mediante `--dart-define`.
/// Ejemplo:
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<void> initializeIfConfigured() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }

  static SupabaseClient? get clientOrNull =>
      isConfigured ? Supabase.instance.client : null;
}
