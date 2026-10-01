import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_config.dart';
import '../../../../core/storage/session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Feature-local infrastructure providers (avoids circular import with app/dependencies).

final _secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final _sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage(ref.read(_secureStorageProvider));
});

final _appConfigProvider = Provider<AppConfig>((ref) {
  const envName = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  return AppConfig.fromName(envName);
});

final _apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(_appConfigProvider);
  final network = NetworkConfig.fromAppConfig(config);
  final storage = ref.watch(_sessionStorageProvider);
  return ApiClient(
    config: network,
    tokenProvider: () => storage.getToken(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(_appConfigProvider);
  return AuthRepositoryImpl(
    remote: AuthRemoteDataSource(ref.watch(_apiClientProvider)),
    local: AuthLocalDataSource(ref.watch(_sessionStorageProvider)),
    allowDemoFallback: !config.environment.isProduction,
  );
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserSession>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AsyncValue<UserSession>> {
  AuthController(this._repository)
      : super(const AsyncValue.data(UserSession()));

  final AuthRepository _repository;

  void applySession(UserSession session) {
    state = AsyncValue.data(session);
  }

  Future<void> restoreSession() async {
    state = const AsyncValue.loading();
    try {
      final session = await _repository.restoreSession();
      state = AsyncValue.data(session ?? const UserSession());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login({required String identifier, required String password}) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(
        await _repository.login(identifier: identifier, password: password),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String phone,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(
        await _repository.register(email: email, phone: phone, password: password),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(
        await _repository.verifyOtp(identifier: identifier, otp: otp),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> completeProfile({
    required String fullName,
    String? nationality,
  }) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(
        await _repository.completeProfile(
          fullName: fullName,
          nationality: nationality,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(UserSession());
  }

  UserSession get current => state.valueOrNull ?? const UserSession();
}
