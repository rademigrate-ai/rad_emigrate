import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/network_config.dart';
import '../core/services/ai/ai_service.dart';
import '../core/session/session_manager.dart';
import '../core/session/session_provider.dart';
import '../core/storage/session_storage.dart';
import '../features/auth/data/datasources/auth_local_datasource.dart';
import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/providers/auth_controller.dart';

// ── Config ──────────────────────────────────────────────────────────

/// Active app configuration (development by default).
final appConfigProvider = Provider<AppConfig>((ref) {
  const envName = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  return AppConfig.fromName(envName);
});

// ── Storage ─────────────────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(ref.read(secureStorageProvider));
});

// ── Network ─────────────────────────────────────────────────────────

final networkConfigProvider = Provider<NetworkConfig>((ref) {
  return NetworkConfig.fromAppConfig(ref.watch(appConfigProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(networkConfigProvider);
  final sessionManager = ref.watch(sessionManagerProvider);
  return ApiClient(
    config: config,
    tokenProvider: () async => sessionManager.token,
  );
});

// ── Auth datasources & repository ───────────────────────────────────

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSource(ref.read(sessionStorageProvider));
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
});

/// Production [AuthRepository] implementation (replaces mock-only wiring).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    local: ref.watch(authLocalDataSourceProvider),
    allowDemoFallback: !config.environment.isProduction,
  );
});

// ── Session ─────────────────────────────────────────────────────────
// sessionManagerProvider is defined in session_provider.dart

// ── AI ──────────────────────────────────────────────────────────────

final aiServiceProvider = Provider<AiService>((ref) {
  return PlaceholderAiService();
});

// ── Bootstrap ───────────────────────────────────────────────────────

/// Restores persisted authentication state before the app is ready.
/// Single ownership: SessionManager.restore → AuthController state sync.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  final manager = ref.read(sessionManagerProvider);
  final restored = await manager.restore();
  if (restored.isAuthenticated && restored.session != null) {
    // Sync controller so UI and GoRouter redirects see authenticated state.
    ref.read(authControllerProvider.notifier).applySession(restored.session!);
  }
});
