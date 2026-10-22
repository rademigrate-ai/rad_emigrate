import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';

const testOwner = 'a1111111-1111-4111-8111-111111111111';

class MockSupabaseService implements SupabaseClientService {
  MockSupabaseService(this.client);
  @override
  final SupabaseClient client;
  @override
  bool get isInitialized => true;
  @override
  Object? initializationError;
  @override
  Future<bool> initialize() async => true;
}

http.Response rpcJson(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Future<MockSupabaseService> mockSupabaseService(
  Future<http.Response> Function(http.Request) respond,
) async {
  final client = SupabaseClient(
    'http://127.0.0.1:59999',
    'synthetic-local-only',
    httpClient: MockClient((r) async {
      final response = await respond(r);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: r,
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  String b64(Object v) =>
      base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  final token =
      '${b64({'alg': 'none'})}.${b64({'sub': testOwner, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.synthetic';
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'synthetic',
      'expires_in': 3600,
      'token_type': 'bearer',
      'user': {
        'id': testOwner,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
  addTearDown(client.dispose);
  return MockSupabaseService(client);
}
