import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/session/session_manager.dart';
import 'package:rad_emigrate/core/session/session_state.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restored});

  UserSession? restored;
  bool loggedOut = false;

  @override
  Future<UserSession> login({required String identifier, required String password}) async =>
      const UserSession(token: 't', authenticated: true);

  @override
  Future<UserSession> register({equired String email, required String phone, required String password}) async =>
      const UserSession();

  @override
  Future<UserSession> verifyOtp({required String identifier, required String otp}) async =>
      const UserSession(token: 't', authenticated: true);

  @override
  Future<UserSession> completeProfile({required String fullName, String? nationality}) async =>
      UserSession(token: 't', fullName: fullName, authenticated: true, profileComplete: true);

  @override
  Future<UserSession?> restoreSession() async => restored;

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}

void main() {
  group('SessionManager', () {
    test('restore sets authenticated when session present', () async {
      final repo = _FakeAuthRepository(
        restored: const UserSession(token: 'abc', authenticated: true, userId: 'u1'),
      );
      final manager = SessionManager(repo);
      final state = await manager.restore();
      expect(state.status, SessionStatus.authenticated);
      expect(manager.isAuthenticated, isTrue);
      expect(manager.token, 'abc');
    });

    test('restore sets unauthenticated when no session', () async {
      final manager = SessionManager(_FakeAuthRepository());
      final state = await manager.restore();
      expect(state.status, SessionStatus.unauthenticated);
      expect(manager.isAuthenticated, isFalse);
    });

    test('logout clears session', () async {
      final repo = _FakeAuthRepository(
        restored: const UserSession(token: 'abc', authenticated: true),
      );
      final manager = SessionManager(repo);
      await manager.restore();
      await manager.logout();
      expect(manager.isAuthenticated, isFalse);
      expect(repo.loggedOut, isTrue);
    });
  });
}
