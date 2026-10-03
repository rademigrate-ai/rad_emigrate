/// Compile-time Supabase configuration.
///
/// Values are injected at build time and are intentionally not hardcoded.
/// Supply values with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY dart-defines.
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
