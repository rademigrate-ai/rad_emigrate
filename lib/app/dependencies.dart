import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/storage/session_storage.dart';
import '../core/services/ai_service.dart';
import '../features/auth/presentation/providers/auth_controller.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(ref.read(secureStorageProvider));
});

final aiServiceProvider = Provider<AiService>((ref) {
  return PlaceholderAiService();
});

/// Bootstrap provider that restores session on app start.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  // Trigger auth restore by reading the controller.
  ref.read(authControllerProvider);
  await Future<void>.delayed(Duration.zero);
});
