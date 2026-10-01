/// Supabase runtime configuration.
///
/// Values are injected at build time and are intentionally not hardcoded.
/// Example:
/// flutter build web --dart-define=SUPABASE_URL=... 
/// --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      url.isNotEmpty && anonKey.isNotEmpty;
}
