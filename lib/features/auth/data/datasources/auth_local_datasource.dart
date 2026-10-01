import '../../../../core/storage/session_storage.dart';
import '../../domain/entities/user_session.dart';

/// Local session persistence boundary.
class AuthLocalDataSource {
  AuthLocalDataSource(this._storage);

  final SessionStorage _storage;

  Future<void> saveSession(UserSession session) async {
    if (session.token != null) {
      await _storage.saveToken(session.token!);
    }
    await _storage.saveUserMeta(
      userId: session.userId ?? 'unknown',
      email: session.email,
      phone: session.phone,
      fullName: session.fullName,
    );
  }

  Future<UserSession?> readSession() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) return null;
    final meta = await _storage.getUserMeta();
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

  Future<void> clear() => _storage.clear();
}
