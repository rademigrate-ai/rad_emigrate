import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../domain/entities/user_session.dart';

/// Authentication transport boundary.
///
/// Production providers pass [SupabaseClientService]. The ApiClient branch is
/// retained so existing repository tests and development adapters remain
/// source-compatible while the migration is rolled out.
class AuthRemoteDataSource {
  AuthRemoteDataSource(Object backend) : _backend = backend;

  final Object _backend;

  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async {
    if (_backend is ApiClient) {
      final response = await (_backend).post<Map<String, dynamic>>(
        '/auth/login',
        data: {'identifier': identifier, 'password': password},
      );
      return _mapLegacySession(response.data);
    }
    if (identifier.trim().isEmpty || !identifier.contains('@')) {
      throw const ApiException(
        message: 'Supabase email authentication requires an email address.',
        code: 'invalid_email',
      );
    }
    try {
      final response = await _service.client.auth.signInWithPassword(
        email: identifier.trim(),
        password: password,
      );
      return _mapSupabaseSession(response.session);
    } catch (error) {
      throw _apiException(error);
    }
  }

  Future<UserSession> register({
    required String email,
    required String phone,
    required String password,
  }) async {
    if (_backend is ApiClient) {
      final response = await (_backend).post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email, 'phone': phone, 'password': password},
      );
      return _mapLegacySession(response.data);
    }
    try {
      final response = await _service.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {if (phone.trim().isNotEmpty) 'phone': phone.trim()},
      );
      if (response.session == null && response.user != null) {
        return UserSession(
          userId: response.user!.id,
          email: response.user!.email,
          phone: response.user!.phone,
          authenticated: false,
          profileComplete: false,
        );
      }
      return _mapSupabaseSession(response.session, user: response.user);
    } catch (error) {
      throw _apiException(error);
    }
  }

  Future<UserSession> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    if (_backend is ApiClient) {
      final response = await (_backend).post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'identifier': identifier, 'otp': otp},
      );
      return _mapLegacySession(response.data);
    }
    if (!identifier.contains('@')) {
      throw const ApiException(
        message: 'Supabase email OTP requires an email address.',
        code: 'invalid_email',
      );
    }
    try {
      final response = await _service.client.auth.verifyOTP(
        email: identifier.trim(),
        token: otp,
        type: OtpType.email,
      );
      return _mapSupabaseSession(response.session, user: response.user);
    } catch (error) {
      throw _apiException(error);
    }
  }

  Future<UserSession> completeProfile({
    required String fullName,
    String? nationality,
  }) async {
    if (_backend is ApiClient) {
      final response = await (_backend).post<Map<String, dynamic>>(
        '/auth/profile/complete',
        data: {
          'fullName': fullName,
          ...?(nationality == null ? null : {'nationality': nationality}),
        },
      );
      return _mapLegacySession(response.data);
    }
    try {
      final user = _service.client.auth.currentUser;
      if (user == null) throw const ApiException(message: 'No active session.');
      await _service.client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'phone': user.phone,
        'full_name': fullName,
        'country': nationality,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return _mapSupabaseSession(
        _service.client.auth.currentSession,
        user: user,
        fullName: fullName,
      );
    } catch (error) {
      throw _apiException(error);
    }
  }

  Future<void> logout() async {
    if (_backend is ApiClient) {
      try {
        await (_backend).post<void>('/auth/logout');
      } on ApiException {
        // Local logout still proceeds.
      }
      return;
    }
    try {
      await _service.client.auth.signOut();
    } catch (error) {
      throw _apiException(error);
    }
  }

  Future<UserSession?> restoreSession() async {
    if (_backend is ApiClient) return null;
    final session = _service.client.auth.currentSession;
    if (session == null) return null;
    return _mapSupabaseSession(session);
  }

  SupabaseClientService get _service => _backend as SupabaseClientService;

  UserSession _mapSupabaseSession(
    Session? session, {
    User? user,
    String? fullName,
  }) {
    final resolvedUser = user ?? _service.client.auth.currentUser;
    if (session == null || resolvedUser == null) {
      throw const ApiException(message: 'No active Supabase session.');
    }
    final metadata = resolvedUser.userMetadata ?? const <String, dynamic>{};
    final resolvedName = fullName ?? metadata['full_name'] as String?;
    return UserSession(
      token: session.accessToken,
      userId: resolvedUser.id,
      email: resolvedUser.email,
      phone: resolvedUser.phone,
      fullName: resolvedName,
      authenticated: true,
      profileComplete: resolvedName != null && resolvedName.isNotEmpty,
    );
  }

  UserSession _mapLegacySession(Map<String, dynamic>? data) {
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

  ApiException _apiException(Object error) {
    if (error is ApiException) return error;
    if (error is AuthException) {
      return ApiException(message: error.message, code: error.statusCode);
    }
    if (error is PostgrestException) {
      return ApiException(message: error.message, code: error.code);
    }
    return ApiException(message: error.toString(), code: 'supabase_error');
  }
}
