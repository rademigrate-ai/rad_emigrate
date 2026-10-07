import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/auth/data/datasources/auth_remote_datasource.dart';

class _Backend implements SupabaseClientService {
  _Backend(this.client);
  @override
  final SupabaseClient client;
  @override
  bool get isInitialized => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'supplementary profile network failure retains valid signed-in session',
    () async {
      final client = SupabaseClient(
        'https://local-fixture.invalid',
        'fixture-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/auth/v1/token')) {
            return http.Response(
              jsonEncode({
                'access_token': 'fixture-access-token',
                'refresh_token': 'fixture-refresh-token',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': 'test-user',
                  'aud': 'authenticated',
                  'email': 'test@example.org',
                  'app_metadata': {},
                  'user_metadata': {},
                  'created_at': '2026-10-07T00:00:00Z',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          throw http.ClientException('temporary profile connection failure');
        }),
      );
      addTearDown(client.dispose);
      final session = await AuthRemoteDataSource(_Backend(client))
          .login(identifier: 'test@example.org', password: 'fixture-only');
      expect(session.isAuthenticated, isTrue);
      expect(session.userId, 'test-user');
      expect(client.auth.currentSession, isNotNull);
      expect(session.fullName, isNull);
    },
  );
}
