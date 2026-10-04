import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';

class AdminAiConfigRepository {
  const AdminAiConfigRepository(this._supabase);
  final SupabaseClientService _supabase;

  Future<void> configureProvider(Map<String, Object?> values) async {
    if (!_supabase.isInitialized) throw StateError('Supabase is not configured.');
    await _supabase.client.rpc('configure_ai_provider', params: values);
  }
}

final adminAiConfigRepositoryProvider = Provider<AdminAiConfigRepository>(
  (ref) => AdminAiConfigRepository(ref.watch(supabaseClientServiceProvider)),
);
