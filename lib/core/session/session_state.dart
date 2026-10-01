import '../../features/auth/domain/entities/user_session.dart';

/// Immutable session snapshot for the application.
enum SessionStatus { unknown, unauthenticated, authenticated }

class SessionState {
  const SessionState({this.status = SessionStatus.unknown, this.session});

  final SessionStatus status;
  final UserSession? session;

  bool get isAuthenticated =>
      status == SessionStatus.authenticated &&
      (session?.isAuthenticated ?? false);

  String? get token => session?.token;

  SessionState copyWith({
    SessionStatus? status,
    UserSession? session,
    bool clearSession = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
    );
  }

  static const unknown = SessionState();
  static const unauthenticated = SessionState(
    status: SessionStatus.unauthenticated,
  );
}
