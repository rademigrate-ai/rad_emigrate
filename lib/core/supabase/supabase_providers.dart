import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_client.dart';
import 'supabase_storage.dart';

final supabaseClientServiceProvider = Provider<SupabaseClientService>((ref) {
  return SupabaseClientService.instance;
});

final supabaseStorageServiceProvider = Provider<SupabaseStorageService>((ref) {
  return SupabaseStorageService(ref.watch(supabaseClientServiceProvider));
});
