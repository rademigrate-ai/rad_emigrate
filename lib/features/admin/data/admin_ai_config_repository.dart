import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';

class AdminAiOperationException implements Exception {
  const AdminAiOperationException(this.code);
  final String? code;
}

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
    String apiKey = '',
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

  Future<Map<String, dynamic>> testProvider(String providerId) async {
    return _invoke('test_provider', providerId);
  }

  Future<Map<String, dynamic>> discoverModels(String providerId) async {
    return _invoke('discover_models', providerId);
  }

  Future<Map<String, dynamic>> _invoke(String action, String providerId) async {
    try {
      final response = await _supabase.client.functions.invoke(
        'ai-orchestrator',
        body: {'action': action, 'provider_id': providerId},
      );
      return _responseMap(response.data);
    } on FunctionException catch (error) {
      final details = error.details;
      throw AdminAiOperationException(
        details is Map ? details['error'] as String? : null,
      );
    }
  }

  Future<void> configureModel({
    required String modelId,
    required bool enabled,
    required String runtimeScope,
    required int priority,
    required int maxOutputTokens,
  }) async {
    await _supabase.client.rpc(
      'set_ai_model_configuration',
      params: {
        'p_model_id': modelId,
        'p_enabled': enabled,
        'p_runtime_scope': runtimeScope,
        'p_priority': priority,
        'p_max_output_tokens': maxOutputTokens,
      },
    );
  }

  Map<String, dynamic> _responseMap(Object? value) {
    if (value is! Map) throw const FormatException('invalid_ai_response');
    final result = value.cast<String, dynamic>();
    if (result['error'] != null)
      throw AdminAiOperationException(
        result['error'] is String ? result['error'] as String : null,
      );
    return result;
  }
}

final adminAiConfigRepositoryProvider = Provider<AdminAiConfigRepository>(
  (ref) => AdminAiConfigRepository(ref.watch(supabaseClientServiceProvider)),
);
