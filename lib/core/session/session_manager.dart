import '../../features/auth/domain/entities/user_session.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import 'session_state.dart';

/// Owns authentication lifecycle and session restoration.
///
/// Single entry point for bootstrap → restore → auth state.
class SessionManager {
  SessionManager(this._authRepository);

  final AuthRepository _authRepository;

  SessionState _state = SessionState.unknown;

  SessionState get state => _state;

  bool get isAuthenticated => _state.isAuthenticated;

  String? get token => _state.token;

  UserSession? get session => _state.session;

  /// Restores persisted session at application start.
  Future<SessionState> restore() async {
    try {
      final restored = await _authRepository.restoreSession();
      if (restored != null && restored.isAuthenticated) {
        _state = SessionState(
          status: SessionStatus.authenticated,
          session: restored,
        );
      } else {
        _state = SessionState.unauthenticated;
      }
    } catch (_) {
      _state = SessionState.unauthenticated;
    }
    return _state;
  }

  void setAuthenticated(UserSession session) {
    _state = SessionState(
      status: SessionStatus.authenticated,
      session: session,
    );
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _state = SessionState.unauthenticated;
  }

  void clear() {
    _state = SessionState.unauthenticated;
  }
}
