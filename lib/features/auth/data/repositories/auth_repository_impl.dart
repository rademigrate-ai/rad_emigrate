import '../../../../core/network/api_exception.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

/// Production auth repository coordinating Supabase Auth and local token cache.
///
/// Local storage is used only to persist a verified Supabase session snapshot;
/// it never fabricates users or silently authenticates when Supabase fails.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.remote, required this.local});

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;

  @override
  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw const ApiException(
        message: 'Password is required.',
        code: 'invalid_password',
      );
    }
    final session = await remote.login(
      identifier: identifier,
      password: password,
    );
    await local.saveSession(session);
    return session;
  }

  @override
  Future<UserSession> register({
    required String email,
    required String phone,
    required String password,
  }) async {
    final session = await remote.register(
      email: email,
      phone: phone,
      password: password,
    );
    if (session.isAuthenticated) await local.saveSession(session);
    return session;
  }

  @override
  Future<void> resendOtp({required String identifier}) =>
      remote.resendOtp(identifier: identifier);

  @override
  Future<UserSession> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    final session = await remote.verifyOtp(identifier: identifier, otp: otp);
    await local.saveSession(session);
    return session;
  }

  @override
  Future<UserSession> completeProfile({
    required String fullName,
    String? nationality,
  }) async {
    final session = await remote.completeProfile(
      fullName: fullName,
      nationality: nationality,
    );
    await local.saveSession(session);
    return session;
  }

  @override
  Future<UserSession?> restoreSession() async {
    final session = await remote.restoreSession();
    if (session != null && session.isAuthenticated) {
      await local.saveSession(session);
      return session;
    }
    await local.clear();
    return null;
  }

  @override
  Future<void> logout() async {
    try {
      await remote.logout();
    } finally {
      await local.clear();
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) =>
      remote.requestPasswordReset(email: email);
}
