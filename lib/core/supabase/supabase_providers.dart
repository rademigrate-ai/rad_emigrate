import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_client.dart';
import 'supabase_storage.dart';

final supabaseClientServiceProvider = Provider<SupabaseClientService>((ref) {
  return SupabaseClientService.instance;
});

/// Session changes invalidate private UI state before async profile hydration.
final supabaseAuthUserIdProvider = StreamProvider<String?>((ref) {
  final service = ref.watch(supabaseClientServiceProvider);
  if (!service.isInitialized) return Stream.value(null);
  return Stream<String?>.multi((output) {
    final subscription = service.client.auth.onAuthStateChange.listen(
      (event) => output.add(event.session?.user.id),
      onError: output.addError,
    );
    output.add(service.client.auth.currentUser?.id);
    output.onCancel = subscription.cancel;
  });
});

final supabaseStorageServiceProvider = Provider<SupabaseStorageService>((ref) {
  return SupabaseStorageService(ref.watch(supabaseClientServiceProvider));
});
