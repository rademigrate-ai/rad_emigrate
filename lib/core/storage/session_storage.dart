import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  SessionStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'user_email';
  static const _phoneKey = 'user_phone';
  static const _fullNameKey = 'user_full_name';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> saveUserMeta({
    required String userId,
    String? email,
    String? phone,
    String? fullName,
  }) async {
    await _storage.write(key: _userIdKey, value: userId);
    if (email != null) await _storage.write(key: _emailKey, value: email);
    if (phone != null) await _storage.write(key: _phoneKey, value: phone);
    if (fullName != null) await _storage.write(key: _fullNameKey, value: fullName);
  }

  Future<Map<String, String?>> getUserMeta() async {
    return {
      'userId': await _storage.read(key: _userIdKey),
      'email': await _storage.read(key: _emailKey),
      'phone': await _storage.read(key: _phoneKey),
      'fullName': await _storage.read(key: _fullNameKey),
    };
  }

  Future<void> clear() => _storage.deleteAll();
}
