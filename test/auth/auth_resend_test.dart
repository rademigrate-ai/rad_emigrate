import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';

class _FakeAuthRepository implements AuthRepository {
  String? resentIdentifier;
  bool? resentSignup;
  Object? resendError;

  @override
  Future<void> resendOtp({
    required String identifier,
    bool signup = false,
  }) async {
    resentIdentifier = identifier;
    resentSignup = signup;
    if (resendError case final error?) throw error;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<UserSession> register({
    required String email,
    required String phone,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<UserSession?> restoreSession() async => throw UnimplementedError();

  @override
  Future<UserSession> completeProfile({
    required String fullName,
    String? nationality,
  }) async => throw UnimplementedError();

  @override
  Future<UserSession> verifyOtp({
    required String identifier,
    required String otp,
    bool signup = false,
  }) async => throw UnimplementedError();
}

void main() {
  test('resend sends the pending email and preserves signup state', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(repository);
    const pending = UserSession(
      userId: 'pending-user',
      email: 'pending@example.test',
      authenticated: false,
    );
    controller.applySession(pending);

    await controller.resendOtp(identifier: 'pending@example.test');

    expect(repository.resentIdentifier, 'pending@example.test');
    expect(repository.resentSignup, isFalse);
    expect(controller.current.userId, 'pending-user');
    expect(controller.current.email, 'pending@example.test');
    expect(controller.current.isAuthenticated, isFalse);
    controller.dispose();
  });

  test('signup resend mode reaches the repository explicitly', () async {
    final repository = _FakeAuthRepository();
    final controller = AuthController(repository);

    await controller.resendOtp(
      identifier: 'pending@example.test',
      signup: true,
    );

    expect(repository.resentIdentifier, 'pending@example.test');
    expect(repository.resentSignup, isTrue);
    controller.dispose();
  });

  test('resend failure preserves pending signup state', () async {
    final repository = _FakeAuthRepository()
      ..resendError = StateError('rate limited');
    final controller = AuthController(repository);
    controller.applySession(
      const UserSession(
        userId: 'pending-user',
        email: 'pending@example.test',
        authenticated: false,
      ),
    );

    await expectLater(
      controller.resendOtp(identifier: 'pending@example.test'),
      throwsA(isA<StateError>()),
    );

    expect(controller.current.userId, 'pending-user');
    expect(controller.current.isAuthenticated, isFalse);
    controller.dispose();
  });
}
