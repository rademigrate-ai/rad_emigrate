import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/mock_auth_repository.dart';
import '../../domain/entities/user_session.dart';

final authRepositoryProvider = Provider<MockAuthRepository>((ref) {
  return MockAuthRepository();
});

final authControllerProvider = StateNotifierProvider<AuthController, UserSession>((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});

class AuthController extends StateNotifier<UserSession> {
  AuthController(this._repository) : super(const UserSession());

  final MockAuthRepository _repository;

  Future<void> login(String identifier) async {
    state = await _repository.login(identifier);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const UserSession();
  }
}
