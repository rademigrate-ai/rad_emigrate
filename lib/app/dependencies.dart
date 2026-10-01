import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/storage/session_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(ref.read(secureStorageProvider));
});

final appReadyProvider = FutureProvider<void>((ref) async {
  await Future<void>.delayed(Duration.zero);
});
