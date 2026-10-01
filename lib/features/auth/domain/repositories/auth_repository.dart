import '../entities/user_session.dart';

abstract class AuthRepository {
  Future<UserSession> login(String identifier);
  Future<void> logout();
}
