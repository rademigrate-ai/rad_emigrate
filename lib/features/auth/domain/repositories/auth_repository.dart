import '../entities/user_session.dart';

abstract class AuthRepository {
  Future<UserSession> login({required String identifier, required String password});
  Future<UserSession> register({equired String email, required String phone, required String password});
  Future<UserSession> verifyOtp({required String identifier, required String otp});
  Future<UserSession> completeProfile({equired String fullName, String? nationality});
  Future<UserSession?> restoreSession();
  Future<void> logout();
}
