import '../../../../core/network/api_exception.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

/// Production auth repository coordinating remote + local datasources.
///
/// Development fallback: when remote is unreachable, a deterministic demo
/// session is used so the app remains usable without a live backend.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remote,
    required this.local,
    this.allowDemoFallback = true,
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;

  /// When true, network failures fall back to offline demo auth.
  final bool allowDemoFallback;

  static const _demoToken = 'rad-demo-token-2026';
  static const _demoOtp = '123456';

  @override
  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw Exception('Password is required');
    }
    try {
      final session = await remote.login(
        identifier: identifier,
        password: password,
      );
      await local.saveSession(session);
      return session;
    } on ApiException {
      if (!allowDemoFallback) rethrow;
      return _demoLogin(identifier);
    }
  }

  @override
  Future<UserSession> register({
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      return await remote.register(
        email: email,
        phone: phone,
        password: password,
      );
    } on ApiException {
      if (!allowDemoFallback) rethrow;
      return UserSession(
        email: email,
        phone: phone,
        authenticated: false,
        profileComplete: false,
      );
    }
  }

  @override
  Future<UserSession> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    try {
      final session = await remote.verifyOtp(identifier: identifier, otp: otp);
      await local.saveSession(session);
      return session;
    } on ApiException {
      if (!allowDemoFallback) rethrow;
      if (otp != _demoOtp) {
        throw Exception('Invalid OTP. Use 123456 for demo.');
      }
      final session = UserSession(
        token: _demoToken,
        userId: 'user-demo-001',
        email: identifier.contains('@') ? identifier : null,
        phone: identifier.contains('@') ? null : identifier,
        authenticated: true,
        profileComplete: false,
      );
      await local.saveSession(session);
      return session;
    }
  }

  @override
  Future<UserSession> completeProfile({
    required String fullName,
    String? nationality,
  }) async {
    try {
      final session = await remote.completeProfile(
        fullName: fullName,
        nationality: nationality,
      );
      await local.saveSession(session);
      return session;
    } on ApiException {
      if (!allowDemoFallback) rethrow;
      final existing = await local.readSession();
      final session = UserSession(
        token: existing?.token ?? _demoToken,
        userId: existing?.userId ?? 'user-demo-001',
        email: existing?.email,
        phone: existing?.phone,
        fullName: fullName,
        authenticated: true,
        profileComplete: true,
      );
      await local.saveSession(session);
      return session;
    }
  }

  @override
  Future<UserSession?> restoreSession() async {
    try {
      final session = await remote.restoreSession();
      if (session != null) {
        await local.saveSession(session);
        return session;
      }
    } on ApiException {
      if (!allowDemoFallback) rethrow;
    }
    return local.readSession();
  }

  @override
  Future<void> logout() async {
    try {
      await remote.logout();
    } finally {
      await local.clear();
    }
  }

  Future<UserSession> _demoLogin(String identifier) async {
    final session = UserSession(
      token: _demoToken,
      userId: 'user-demo-001',
      email: identifier.contains('@') ? identifier : null,
      phone: identifier.contains('@') ? null : identifier,
      fullName: 'Demo User',
      authenticated: true,
      profileComplete: true,
    );
    await local.saveSession(session);
    return session;
  }
}
