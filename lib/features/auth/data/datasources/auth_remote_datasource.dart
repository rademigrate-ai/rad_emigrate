import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/user_session.dart';

/// Remote authentication API boundary.
///
/// When the backend is unavailable, methods throw [ApiException] so the
/// repository can fall back to demo behaviour in development.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final ApiClient _client;

  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'identifier': identifier, 'password': password},
      );
      return _mapSession(response.data);
    } on ApiException {
      rethrow;
    }
  }

  Future<UserSession> register({
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'phone': phone, 'password': password},
    );
    return _mapSession(response.data);
  }

  Future<UserSession> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/otp/verify',
      data: {'identifier': identifier, 'otp': otp},
    );
    return _mapSession(response.data);
  }

  Future<UserSession> completeProfile({
    required String fullName,
    String? nationality,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/auth/profile/complete',
      data: {
        'fullName': fullName,
        ...?(nationality == null ? null : {'nationality': nationality}),
      },
    );
    return _mapSession(response.data);
  }

  Future<void> logout() async {
    try {
      await _client.post<void>('/auth/logout');
    } on ApiException {
      // Local logout still proceeds even if remote fails.
    }
  }

  UserSession _mapSession(Map<String, dynamic>? data) {
    if (data == null) {
      throw const ApiException(
        message: 'Empty auth response',
        code: 'empty_response',
      );
    }
    final user = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    return UserSession(
      token: data['token'] as String? ?? data['accessToken'] as String?,
      userId: user['id'] as String? ?? user['userId'] as String?,
      email: user['email'] as String?,
      phone: user['phone'] as String?,
      fullName: user['fullName'] as String? ?? user['name'] as String?,
      authenticated: true,
      profileComplete: user['profileComplete'] as bool? ?? false,
    );
  }
}
