import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/core/storage/session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, required String? value, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    return _store[key];
  }

  @override
  Future<void> deleteAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, MacOsOptions? mOptions, WindowsOptions? wOptions}) async {
    _store.clear();
  }
}

void main() {
  late MockAuthRepository repository;
  late SessionStorage storage;

  setUp(() {
    storage = SessionStorage(MemorySecureStorage());
    repository = MockAuthRepository(storage);
  });

  test('login returns authenticated session and stores token', () async {
    final session = await repository.login(identifier: 'demo@radvisa.com', password: 'secret');
    expect(session.isAuthenticated, isTrue);
    expect(session.token, isNotNull);
    final token = await storage.getToken();
    expect(token, equals(session.token));
  });

  test('logout clears session', () async {
    await repository.login(identifier: 'demo@radvisa.com', password: 'secret');
    await repository.logout();
    final restored = await repository.restoreSession();
    expect(restored, isNull);
  });

  test('verifyOtp with correct code authenticates', () async {
    final session = await repository.verifyOtp(identifier: 'demo@radvisa.com', otp: '123456');
    expect(session.isAuthenticated, isTrue);
    expect(session.profileComplete, isFalse);
  });

  test('verifyOtp with wrong code throws', () async {
    expect(
      () => repository.verifyOtp(identifier: 'x', otp: '000000'),
      throwsException,
    );
  });

  test('UserSession copyWith preserves values', () {
    const original = UserSession(token: 't', authenticated: true, fullName: 'A');
    final updated = original.copyWith(fullName: 'B');
    expect(updated.token, 't');
    expect(updated.fullName, 'B');
    expect(updated.authenticated, isTrue);
  });
}
