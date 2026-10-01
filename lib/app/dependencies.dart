import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/network_config.dart';
import '../core/services/ai/ai_service.dart';
import '../core/session/session_manager.dart';
import '../core/session/session_state.dart';
import '../core/storage/session_storage.dart';
import '../core/supabase/supabase_providers.dart';
import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/ai_assistant/data/ai_session_repository.dart';

// ── Config ──────────────────────────────────────────────────────────

final appConfigProvider = Provider<AppConfig>((ref) {
  const envName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  return AppConfig.fromName(envName);
});

// ── Storage (shared app-level handles) ──────────────────────────────

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
  final storage = ref.watch(sessionStorageProvider);
  return ApiClient(config: config, tokenProvider: () => storage.getToken());
});

// Auth repository + controller providers live in auth_controller.dart
// (authRepositoryProvider, authControllerProvider).

// ── Session ─────────────────────────────────────────────────────────

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(ref.watch(authRepositoryProvider));
});

final sessionStateProvider = Provider<SessionState>((ref) {
  final auth = ref.watch(authControllerProvider);
  final session = auth.valueOrNull;
  if (session != null && session.isAuthenticated) {
    return SessionState(status: SessionStatus.authenticated, session: session);
  }
  if (auth.isLoading) {
    return SessionState.unknown;
  }
  return SessionState.unauthenticated;
});

// ── AI ──────────────────────────────────────────────────────────────

final aiServiceProvider = Provider<AiService>((ref) {
  return UnavailableAiService();
});

final aiSessionRepositoryProvider = Provider<AiSessionRepository>((ref) {
  return AiSessionRepository(ref.watch(supabaseClientServiceProvider));
});

// ── Bootstrap ───────────────────────────────────────────────────────

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final supabase = ref.read(supabaseClientServiceProvider);
  await supabase.initialize();
  if (supabase.isInitialized) {
    final authController = ref.read(authControllerProvider.notifier);
    final authDatasource = AuthRemoteDataSource(supabase);
    final subscription = supabase.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session == null) {
        authController.clearSession();
      } else {
        authController.applySession(
          authDatasource.sessionFromAuthSession(session),
        );
      }
    });
    ref.onDispose(subscription.cancel);
  }
  final manager = ref.read(sessionManagerProvider);
  final restored = await manager.restore();
  if (restored.isAuthenticated && restored.session != null) {
    ref.read(authControllerProvider.notifier).applySession(restored.session!);
  }
});
