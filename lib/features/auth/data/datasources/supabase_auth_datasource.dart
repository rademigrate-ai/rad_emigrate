import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_session.dart';

class SupabaseAuthDataSource {
  SupabaseAuthDataSource(this._client);

  final SupabaseClient? _client;

  Future<UserSession> login({
    required String email,
    required String password,
  }) async {
    final client = _requireClient();
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    return _mapSession(response.session, response.user);
  }

  Future<UserSession> register({
    required String email,
    required String password,
  }) async {
    final client = _requireClient();
    final response = await client.auth.signUp(email: email, password: password);

    return _mapSession(response.session, response.user);
  }

  Future<void> logout() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
  }

  UserSession restore() {
    final session = _client?.auth.currentSession;
    final user = _client?.auth.currentUser;
    return _mapSession(session, user);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    return client;
  }

  UserSession _mapSession(Session? session, User? user) {
    return UserSession(
      token: session?.accessToken,
      userId: user?.id,
      email: user?.email,
      authenticated: user != null,
      profileComplete: false,
    );
  }
}
