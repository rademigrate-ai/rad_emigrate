import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class RadSupabaseClient {
  RadSupabaseClient._();

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  static SupabaseClient? get instance {
    if (!SupabaseConfig.isConfigured) {
      return null;
    }
    return Supabase.instance.client;
  }
}
