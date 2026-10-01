import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/mock_auth_repository.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../app/dependencies.dart';
import '../../../../core/routing/app_router.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository(ref.read(sessionStorageProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserSession>>((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});

class AuthController extends StateNotifier<AsyncValue<UserSession>> {
  AuthController(this._repository) : super(const AsyncValue.data(UserSession())) {
    _restore();
  }

  final AuthRepository _repository;

  Future<void> _restore() async {
    state = const AsyncValue.loading();
    try {
      final session = await _repository.restoreSession();
      final resolved = session ?? const UserSession();
      state = AsyncValue.data(resolved);
      sessionNotifier.value = resolved.isAuthenticated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      sessionNotifier.value = false;
    }
  }

  Future<void> login({required String identifier, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final session = await _repository.login(identifier: identifier, password: password);
      state = AsyncValue.data(session);
      sessionNotifier.value = session.isAuthenticated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      sessionNotifier.value = false;
      rethrow;
    }
  }

  Future<void> register({required String email, required String phone, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final session = await _repository.register(email: email, phone: phone, password: password);
      state = AsyncValue.data(session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> verifyOtp({required String identifier, required String otp}) async {
    state = const AsyncValue.loading();
    try {
      final session = await _repository.verifyOtp(identifier: identifier, otp: otp);
      state = AsyncValue.data(session);
      sessionNotifier.value = session.isAuthenticated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      sessionNotifier.value = false;
      rethrow;
    }
  }

  Future<void> completeProfile({required String fullName, String? nationality}) async {
    state = const AsyncValue.loading();
    try {
      final session = await _repository.completeProfile(fullName: fullName, nationality: nationality);
      state = AsyncValue.data(session);
      sessionNotifier.value = session.isAuthenticated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(UserSession());
    sessionNotifier.value = false;
  }

  UserSession get current => state.valueOrNull ?? const UserSession();
}
