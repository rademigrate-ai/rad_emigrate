import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/ai_assistant/data/ai_session_repository.dart';

import '../support/mock_supabase_service.dart';

void main() {
  test('rename persists a title through the current owner and scope', () async {
    final service = await mockSupabaseService((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['user_id'], 'eq.$testOwner');
      expect(request.url.queryParameters['scope'], 'eq.user');
      expect(request.url.queryParameters['id'], 'eq.session');
      expect(jsonDecode(request.body), {'title': 'Reviewed title'});
      return rpcJson({
        'id': 'session',
        'user_id': testOwner,
        'question_count': 1,
        'created_at': '2026-11-05T00:00:00Z',
        'title': 'Reviewed title',
      });
    });
    final renamed = await AiSessionRepository(service).renameSession(
      sessionId: 'session',
      userId: testOwner,
      title: ' Reviewed title ',
    );
    expect(renamed.title, 'Reviewed title');
  });

  test(
    'delete requires an acknowledged owner-scoped database deletion',
    () async {
      final service = await mockSupabaseService((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.queryParameters['user_id'], 'eq.$testOwner');
        expect(request.url.queryParameters['scope'], 'eq.user');
        return rpcJson([
          {'id': 'session'},
        ]);
      });
      await AiSessionRepository(service)
          .deleteSession(sessionId: 'session', userId: testOwner);
    },
  );

  test('foreign identity and unacknowledged deletion never succeed', () async {
    var calls = 0;
    final service = await mockSupabaseService((request) async {
      calls++;
      return rpcJson([]);
    });
    final repository = AiSessionRepository(service);
    await expectLater(
      repository.deleteSession(sessionId: 'session', userId: 'foreign'),
      throwsStateError,
    );
    expect(calls, 0);
    await expectLater(
      repository.deleteSession(sessionId: 'session', userId: testOwner),
      throwsStateError,
    );
    expect(calls, 1);
  });
}
