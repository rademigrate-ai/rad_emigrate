import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/app/dependencies.dart';
import 'package:rad_emigrate/core/services/ai/ai_request.dart';
import 'package:rad_emigrate/core/services/ai/ai_response.dart';
import 'package:rad_emigrate/core/services/ai/ai_service.dart';
import 'package:rad_emigrate/features/ai_assistant/data/ai_session_repository.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _AuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sessions implements AiSessionRepository {
  final saved = <({String role, String content})>[];
  final scopes = <String>[];
  List<AiSessionMessage> restored = [];
  Completer<void>? restoreGate;
  int created = 0;
  @override
  Future<List<AiSession>> listSessions(
    String userId, {
    String scope = 'user',
  }) async {
    scopes.add(scope);
    await restoreGate?.future;
    return restored.isEmpty
        ? []
        : [
            AiSession(
              id: 'session',
              userId: userId,
              questionCount: 1,
              createdAt: DateTime(2026),
            ),
          ];
  }

  @override
  Future<AiSession> createSession(
    String userId, {
    String scope = 'user',
  }) async {
    scopes.add(scope);
    created++;
    return AiSession(
      id: 'session',
      userId: userId,
      questionCount: 0,
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<List<AiSessionMessage>> history(String sessionId) async => restored;
  @override
  Future<void> saveMessage({
    required String sessionId,
    required String userId,
    required String role,
    required String content,
  }) async {
    saved.add((role: role, content: content));
  }
}

class _Ai implements AiService {
  final requests = <AiRequest>[];
  bool fail = true;
  bool throwTransport = false;
  @override
  bool get isAvailable => true;
  @override
  Future<String> ask(String prompt) async => '';
  @override
  Future<AiResponse> complete(AiRequest request) async {
    requests.add(request);
    if (throwTransport) throw StateError('transport failure');
    return fail
        ? const AiResponse(
            text: 'Credential rejected',
            errorCode: 'provider_unauthorized',
            uncertain: true,
          )
        : const AiResponse(text: 'Verified answer');
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Ai ai,
  _Sessions sessions, {
  bool admin = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiServiceProvider.overrideWithValue(ai),
        aiSessionRepositoryProvider.overrideWithValue(sessions),
        authControllerProvider.overrideWith(
          (ref) => AuthController(_AuthRepository())
            ..applySession(
              const UserSession(userId: 'user', authenticated: true),
            ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiAssistantPage(adminMode: admin),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester, String prompt) async {
  await tester.enterText(find.byType(TextField), prompt);
  await tester.tap(find.byTooltip('Send message'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'provider failure retries without duplicating persisted user question',
    (tester) async {
      final ai = _Ai();
      final sessions = _Sessions();
      await _pump(tester, ai, sessions);
      await _send(tester, 'My question');
      expect(find.text('Credential rejected'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      ai.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(ai.requests, hasLength(2));
      expect(sessions.saved.where((row) => row.role == 'user'), hasLength(1));
      expect(
        sessions.saved.where((row) => row.role == 'assistant'),
        hasLength(1),
      );
      expect(find.text('My question'), findsOneWidget);
      expect(find.text('Credential rejected'), findsNothing);
      expect(find.text('Verified answer'), findsOneWidget);
    },
  );

  testWidgets('restored conversation turns reach subsequent requests', (
    tester,
  ) async {
    final ai = _Ai()..fail = false;
    final sessions = _Sessions()
      ..restored = [
        AiSessionMessage(
          id: 'one',
          sessionId: 'session',
          role: 'user',
          content: 'Earlier question',
          createdAt: DateTime(2026),
        ),
        AiSessionMessage(
          id: 'two',
          sessionId: 'session',
          role: 'assistant',
          content: 'Earlier answer',
          createdAt: DateTime(2026),
        ),
      ];
    await _pump(tester, ai, sessions);
    await _send(tester, 'Follow up');
    expect(ai.requests.single.history.map((m) => m.text), [
      'Earlier question',
      'Earlier answer',
    ]);
    expect(ai.requests.single.history.map((m) => m.isUser), [true, false]);
    expect(ai.requests.single.conversationId, 'session');
    expect(sessions.created, 0);
  });

  testWidgets('send waits for history and retains restored session', (
    tester,
  ) async {
    final ai = _Ai()..fail = false;
    final gate = Completer<void>();
    final sessions = _Sessions()
      ..restoreGate = gate
      ..restored = [
        AiSessionMessage(
          id: 'one',
          sessionId: 'session',
          role: 'user',
          content: 'Earlier question',
          createdAt: DateTime(2026),
        ),
      ];
    await _pump(tester, ai, sessions);
    await tester.enterText(find.byType(TextField), 'Follow up');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    expect(ai.requests, isEmpty);
    expect(sessions.saved, isEmpty);
    gate.complete();
    await tester.pumpAndSettle();
    expect(ai.requests.single.conversationId, 'session');
    expect(ai.requests.single.history.single.text, 'Earlier question');
    expect(sessions.created, 0);
  });

  testWidgets('transport failure is actionable and admin retry retains scope', (
    tester,
  ) async {
    final ai = _Ai()..throwTransport = true;
    final sessions = _Sessions();
    await _pump(tester, ai, sessions, admin: true);
    await _send(tester, 'Research question');
    expect(
      find.text('The AI request could not be completed. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    ai
      ..throwTransport = false
      ..fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      ai.requests.every((request) => request.metadata['scope'] == 'admin'),
      isTrue,
    );
    expect(sessions.scopes.every((scope) => scope == 'admin'), isTrue);
    expect(sessions.saved.where((row) => row.role == 'user'), hasLength(1));
  });
}
