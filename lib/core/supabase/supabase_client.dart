import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class SupabaseClientService {
  SupabaseClientService._();

  static final instance = SupabaseClientService._();

  bool _initialized = false;
  Object? initializationError;

  bool get isInitialized => _initialized;
  SupabaseClient get client => Supabase.instance.client;

  Future<bool> initialize() async {
    if (_initialized) return true;
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: true,
        ),
        debug: false,
      );
      _initialized = true;
      return true;
    } catch (error) {
      initializationError = error;
      return false;
    }
  }
}

/// Compatibility facade for the initial Project 04 foundation commit.
class RadSupabaseClient {
  RadSupabaseClient._();

  static Future<void> initialize() async {
    await SupabaseClientService.instance.initialize();
  }

  static SupabaseClient? get instance {
    final service = SupabaseClientService.instance;
    return service.isInitialized ? service.client : null;
  }
}
