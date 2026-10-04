import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';

class AdminAiConfigRepository {
  const AdminAiConfigRepository(this._supabase);
  final SupabaseClientService _supabase;

  /// Configures or updates an AI provider. The API key is write-only:
  /// stored in Vault server-side and never returned to the client.
  Future<String> configureProvider({
    required String slug,
    required String displayName,
    required String adapter,
    required String baseUrl,
    required String apiKey,
    bool enabled = false,
    int priority = 100,
  }) async {
    if (!_supabase.isInitialized) {
      throw StateError('Supabase is not configured.');
    }
    final result = await _supabase.client.rpc(
      'configure_ai_provider',
      params: {
        'p_slug': slug,
        'p_display_name': displayName,
        'p_adapter': adapter,
        'p_base_url': baseUrl,
        'p_api_key': apiKey,
        'p_enabled': enabled,
        'p_priority': priority,
      },
    );
    return result.toString();
  }
}

final adminAiConfigRepositoryProvider = Provider<AdminAiConfigRepository>(
  (ref) => AdminAiConfigRepository(ref.watch(supabaseClientServiceProvider)),
);
