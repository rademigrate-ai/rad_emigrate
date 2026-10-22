import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_controller.dart';
import '../../../core/supabase/supabase_providers.dart';

typedef NotificationReader = Future<List<Map<String, dynamic>>> Function(
  String userId,
);

/// No private result cache: each refresh is bound to the verified SDK actor.
final notificationReaderProvider = Provider<NotificationReader>((ref) {
  final service = ref.watch(supabaseClientServiceProvider);
  return (userId) async {
    bool current() =>
        service.isInitialized &&
        ref.read(authenticatedUserIdProvider) == userId &&
        service.client.auth.currentUser?.id == userId;
    if (!current()) throw StateError('Private notification session required');
    final rows = await service.client
        .from('notifications')
        .select('id, type, title, body, action_path, read_at, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .timeout(const Duration(seconds: 10));
    if (!current()) return [];
    return List<Map<String, dynamic>>.from(rows);
  };
});
