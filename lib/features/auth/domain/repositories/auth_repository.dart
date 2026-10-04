import '../entities/user_session.dart';

abstract class AuthRepository {
  Future<UserSession> login({
    required String identifier,
    required String password,
  });
  Future<UserSession> register({
    required String email,
    required String phone,
    required String password,
  });
  Future<void> resendOtp({required String identifier});
  Future<UserSession> verifyOtp({
    required String identifier,
    required String otp,
  });
  Future<UserSession> completeProfile({
    required String fullName,
    String? nationality,
  });
  Future<UserSession?> restoreSession();
  Future<void> logout();

  /// Request a password-reset email. Does not reveal whether the account exists.
  Future<void> requestPasswordReset({required String email});
}
