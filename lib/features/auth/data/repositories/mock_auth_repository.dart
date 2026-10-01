import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/storage/session_storage.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._sessionStorage);

  final SessionStorage _sessionStorage;

  static const _demoToken = 'rad-demo-token-2026';
  static const _demoOtp = '123456';

  @override
  Future<UserSession> login({required String identifier, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (password.isEmpty) {
      throw Exception('Password is required');
    }
    final session = UserSession(
      token: _demoToken,
      userId: 'user-demo-001',
      email: identifier.contains('@') ? identifier : null,
      phone: identifier.contains('@') ? null : identifier,
      fullName: 'Demo User',
      authenticated: true,
      profileComplete: true,
    );
    await _sessionStorage.saveToken(session.token!);
    await _sessionStorage.saveUserMeta(
      userId: session.userId!,
      email: session.email,
      phone: session.phone,
      fullName: session.fullName,
    );
    return session;
  }

  @override
  Future<UserSession> register({required String email, required String phone, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return UserSession(
      email: email,
      phone: phone,
      authenticated: false,
      profileComplete: false,
    );
  }

  @override
  Future<UserSession> verifyOtp({required String identifier, required String otp}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
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
    await _sessionStorage.saveToken(session.token!);
    await _sessionStorage.saveUserMeta(
      userId: session.userId!,
      email: session.email,
      phone: session.phone,
    );
    return session;
  }

  @override
  Future<UserSession> completeProfile({required String fullName, String? nationality}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final token = await _sessionStorage.getToken();
    final meta = await _sessionStorage.getUserMeta();
    final session = UserSession(
      token: token,
      userId: meta['userId'],
      email: meta['email'],
      phone: meta['phone'],
      fullName: fullName,
      authenticated: true,
      profileComplete: true,
    );
    await _sessionStorage.saveUserMeta(
      userId: session.userId ?? 'user-demo-001',
      email: session.email,
      phone: session.phone,
      fullName: fullName,
    );
    return session;
  }

  @override
  Future<UserSession?> restoreSession() async {
    final token = await _sessionStorage.getToken();
    if (token == null || token.isEmpty) return null;
    final meta = await _sessionStorage.getUserMeta();
    return UserSession(
      token: token,
      userId: meta['userId'],
      email: meta['email'],
      phone: meta['phone'],
      fullName: meta['fullName'],
      authenticated: true,
      profileComplete: meta['fullName'] != null && meta['fullName']!.isNotEmpty,
    );
  }

  @override
  Future<void> logout() async {
    await _sessionStorage.clear();
  }
}
