import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../domain/entities/user_session.dart';

/// Authentication transport boundary.
///
/// Production providers pass [SupabaseClientService]. The ApiClient branch is
/// retained for source compatibility with legacy adapters and tests.
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
    _ensureSupabaseReady();
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
      return await _mapSupabaseSession(response.session);
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
    _ensureSupabaseReady();
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
      return await _mapSupabaseSession(response.session, user: response.user);
    } catch (error) {
      throw _apiException(error);
    }
  }

  Future<void> resendOtp({
    required String identifier,
    bool signup = false,
  }) async {
    final email = identifier.trim();
    if (!email.contains('@')) {
      throw const ApiException(
        message: 'Supabase email authentication requires an email address.',
        code: 'invalid_email',
      );
    }
    if (_backend is ApiClient) {
      await (_backend).post<void>(
        '/auth/otp/resend',
        data: {'identifier': email},
      );
      return;
    }
    _ensureSupabaseReady();
    try {
      if (signup) {
        await _service.client.auth.resend(type: OtpType.signup, email: email);
      } else {
        await _service.client.auth.signInWithOtp(
          email: email,
          shouldCreateUser: false,
        );
      }
    } catch (error) {
      throw _apiException(error);
    }
  }

  Future<UserSession> verifyOtp({
    required String identifier,
    required String otp,
    bool signup = false,
  }) async {
    if (_backend is ApiClient) {
      final response = await (_backend).post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'identifier': identifier, 'otp': otp},
      );
      return _mapLegacySession(response.data);
    }
    _ensureSupabaseReady();
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
        type: signup ? OtpType.signup : OtpType.email,
      );
      return await _mapSupabaseSession(response.session, user: response.user);
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
    _ensureSupabaseReady();
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
      return await _mapSupabaseSession(
        _service.client.auth.currentSession,
        user: user,
        fullName: fullName,
      );
    } catch (error) {
      throw _apiException(error);
    }
  }

  /// Sends a password-recovery email via Supabase Auth.
  ///
  /// On web, [redirectTo] points at `/reset-password` on the current origin so
  /// Render SPA routing can deliver the recovery session to the set-password UI.
  Future<void> requestPasswordReset({required String email}) async {
    final trimmed = email.trim();
    if (!trimmed.contains('@')) {
      throw const ApiException(
        message: 'A valid email address is required.',
        code: 'invalid_email',
      );
    }
    if (_backend is ApiClient) {
      await (_backend).post<void>(
        '/auth/password/reset',
        data: {'email': trimmed},
      );
      return;
    }
    _ensureSupabaseReady();
    try {
      String? redirectTo;
      if (kIsWeb) {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && origin != 'null') {
          redirectTo = '$origin/reset-password';
        }
      }
      await _service.client.auth.resetPasswordForEmail(
        trimmed,
        redirectTo: redirectTo,
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
    _ensureSupabaseReady();
    try {
      await _service.client.auth.signOut();
    } catch (error) {
      throw _apiException(error);
    }
  }

  Future<UserSession?> restoreSession() async {
    if (_backend is ApiClient) return null;
    _ensureSupabaseReady();
    final session = _service.client.auth.currentSession;
    if (session == null) return null;
    return _mapSupabaseSession(session);
  }

  SupabaseClientService get _service => _backend as SupabaseClientService;

  Future<UserSession> sessionFromAuthSession(Session session) {
    _ensureSupabaseReady();
    return _mapSupabaseSession(session);
  }

  void _ensureSupabaseReady() {
    if (!_service.isInitialized) {
      throw const ApiException(
        message: 'Supabase is not configured for this build.',
        code: 'supabase_not_configured',
      );
    }
  }

  Future<UserSession> _mapSupabaseSession(
    Session? session, {
    User? user,
    String? fullName,
  }) async {
    final resolvedUser = user ?? _service.client.auth.currentUser;
    if (session == null || resolvedUser == null) {
      throw const ApiException(message: 'No active Supabase session.');
    }

    final metadata = resolvedUser.userMetadata ?? const <String, dynamic>{};
    String? resolvedName = fullName ?? metadata['full_name'] as String?;

    if (resolvedName == null || resolvedName.trim().isEmpty) {
      try {
        final profile = await _service.client
            .from('profiles')
            .select('full_name')
            .eq('id', resolvedUser.id)
            .maybeSingle();
        final profileName = profile?['full_name'] as String?;
        if (profileName != null && profileName.trim().isNotEmpty) {
          resolvedName = profileName;
        }
      } catch (_) {
        // Route protection should fail closed on auth, but a temporarily
        // unavailable profile/name lookup (including network failure) should
        // not invalidate an otherwise valid session. No auth operation is
        // caught here; those retain their normal failure behavior.
      }
    }

    return UserSession(
      token: session.accessToken,
      userId: resolvedUser.id,
      email: resolvedUser.email,
      phone: resolvedUser.phone,
      fullName: resolvedName,
      authenticated: true,
      profileComplete: resolvedName != null && resolvedName.trim().isNotEmpty,
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
    return ApiException(
      message: 'Unexpected Supabase error.',
      code: 'supabase_error',
      cause: error,
    );
  }
}
