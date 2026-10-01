import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<UserSession> login(String identifier) async {
    return const UserSession(token: 'demo-token', authenticated: true);
  }

  @override
  Future<void> logout() async {}
}
