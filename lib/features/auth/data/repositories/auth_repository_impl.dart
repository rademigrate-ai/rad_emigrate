import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../../../core/network/api_exception.dart';

/// Production auth repository coordinating remote + local datasources.
///
/// Development fallback: when remote is unreachable, a deterministic demo
/// session is used so the app remains usable without a live backend.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    this.allowDemoFallback = true,
  })  : _remote = remote,
        _local = local;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

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
      final session = await _remote.login(identifier: identifier, password: password);
      await _local.saveSession(session);
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
      final session = await _remote.register(email: email, phone: phone, password: password);
      return session;
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
      final session = await _remote.verifyOtp(identifier: identifier, otp: otp);
      await _local.saveSession(session);
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
      await _local.saveSession(session);
      return session;
    }
  }

  @override
  Future<UserSession> completeProfile({
    required String fullName,
    String? nationality,
  }) async {
    try {
      final session = await _remote.completeProfile(
        fullName: fullName,
        nationality: nationality,
      );
      await _local.saveSession(session);
      return session;
    } on ApiException {
      if (!allowDemoFallback) rethrow;
      final existing = await _local.readSession();
      final session = UserSession(
        token: existing?.token ?? _demoToken,
        userId: existing?.userId ?? 'user-demo-001',
        email: existing?.email,
        phone: existing?.phone,
        fullName: fullName,
        authenticated: true,
        profileComplete: true,
      );
      await _local.saveSession(session);
      return session;
    }
  }

  @override
  Future<UserSession?> restoreSession() => _local.readSession();

  @override
  Future<void> logout() async {
    try {
      await _remote.logout();
    } finally {
      await _local.clear();
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
    await _local.saveSession(session);
    return session;
  }
}
