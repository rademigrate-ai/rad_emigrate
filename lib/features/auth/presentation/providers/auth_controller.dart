import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';

/// Provider is registered in `app/dependencies.dart` to own the dependency graph.
/// This file only defines the controller type and a late-bound provider key.
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserSession>>((ref) {
  throw UnimplementedError(
    'authControllerProvider must be overridden via dependencies.dart',
  );
});

class AuthController extends StateNotifier<AsyncValue<UserSession>> {
  AuthController(this._repository)
      : super(const AsyncValue.data(UserSession()));

  final AuthRepository _repository;

  /// Apply an already-restored session without re-fetching storage.
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
