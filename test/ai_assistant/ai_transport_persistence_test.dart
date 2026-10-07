import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// Supabase's HTTP transport is exercised with its own transitive test client.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rad_emigrate/core/services/ai/ai_request.dart';
import 'package:rad_emigrate/core/services/ai/supabase_ai_service.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/ai_assistant/data/ai_session_repository.dart';

class _Backend implements SupabaseClientService {
  _Backend(this.client);
  @override
  final SupabaseClient client;
  @override
  bool get isInitialized => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

_Backend _backend(Future<http.Response> Function(http.Request) callback) =>
    _Backend(
      SupabaseClient(
        'https://local-fixture.invalid',
        'fixture-public-key',
        httpClient: MockClient(callback),
      ),
    );

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('AI payload includes history and current prompt once, retaining admin scope', () async {
    Map<String, dynamic>? sent;
    final backend = _backend((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return _json({
        'reply': 'Sourced reply',
        'sources': [
          {'title': 'Official source', 'url': 'https://example.gov'},
        ],
      }, 200);
    });
    final response = await SupabaseAiService(backend).complete(
      const AiRequest(
        prompt: 'Follow up',
        conversationId: 'session',
        metadata: {'scope': 'admin'},
        history: [
          AiConversationMessage(isUser: true, text: 'Earlier question'),
          AiConversationMessage(isUser: false, text: 'Earlier answer'),
        ],
      ),
    );
    expect(sent?['scope'], 'admin');
    expect(sent?['session_id'], 'session');
    expect(sent?['messages'], [
      {'role': 'user', 'content': 'Earlier question'},
      {'role': 'assistant', 'content': 'Earlier answer'},
      {'role': 'user', 'content': 'Follow up'},
    ]);
    expect(response.errorCode, isNull);
    expect(response.sources.single.title, 'Official source');
  });

  test('provider credential rejection remains a localized failure', () async {
    final backend = _backend(
      (request) async => _json({
        'error': 'ai_temporarily_unavailable',
        'code': 'provider_unauthorized',
      }, 503),
    );
    final response = await SupabaseAiService(backend)
        .complete(const AiRequest(prompt: 'Question', locale: 'fa'));
    expect(response.errorCode, 'provider_unauthorized');
    expect(response.uncertain, isTrue);
    expect(response.text, isNot(contains('ai_temporarily_unavailable')));
    expect(RegExp(r'[\u0600-\u06ff]').hasMatch(response.text), isTrue);
  });

  test(
    'history retrieves latest bounded page and returns chronological turns',
    () async {
      final backend = _backend((request) async {
        expect(request.url.queryParameters['order'], 'created_at.desc');
        expect(request.url.queryParameters['limit'], '200');
        return _json([
          {
            'id': 'new',
            'session_id': 'session',
            'role': 'assistant',
            'content': 'Latest answer',
            'created_at': '2026-10-07T11:00:01Z',
          },
          {
            'id': 'older',
            'session_id': 'session',
            'role': 'user',
            'content': 'Earlier question',
            'created_at': '2026-10-07T11:00:00Z',
          },
        ], 200);
      });
      final history = await AiSessionRepository(backend).history('session');
      expect(history.map((message) => message.content), [
        'Earlier question',
        'Latest answer',
      ]);
    },
  );

  for (final failure in ['GET', 'PATCH']) {
    test(
      'committed question remains saved when counter $failure fails',
      () async {
        final calls = <String>[];
        final backend = _backend((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.url.path.endsWith('/ai_session_messages'))
            return http.Response('', 201);
          if (request.method == failure)
            return _json({
              'message': 'fixture count failure',
              'code': '42501',
            }, 403);
          return _json({'question_count': 2}, 200);
        });
        await AiSessionRepository(backend).saveMessage(
          sessionId: 'session',
          userId: 'user',
          role: 'user',
          content: 'Question',
        );
        expect(
          calls.where((call) => call == 'POST /rest/v1/ai_session_messages'),
          hasLength(1),
        );
        expect(calls.any((call) => call.startsWith(failure)), isTrue);
      },
    );
  }

  test(
    'primary message-insert errors still reach caller without updating count',
    () async {
      final calls = <String>[];
      final backend = _backend((request) async {
        calls.add(request.url.path);
        return _json({
          'message': 'fixture insert denied',
          'code': '42501',
        }, 403);
      });
      await expectLater(
        AiSessionRepository(backend).saveMessage(
          sessionId: 'session',
          userId: 'user',
          role: 'user',
          content: 'Question',
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, ['/rest/v1/ai_session_messages']);
    },
  );
}
