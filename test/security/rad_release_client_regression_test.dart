import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../support/rad_contract_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rad_emigrate/core/services/ai/ai_request.dart';
import 'package:rad_emigrate/core/services/ai/ai_response.dart';
import 'package:rad_emigrate/core/services/ai/ai_service.dart';
import 'package:rad_emigrate/app/dependencies.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/features/ai_assistant/data/ai_session_repository.dart';
import 'package:rad_emigrate/core/services/ai/supabase_ai_service.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/providers/ai_prompt_draft_provider.dart';
import 'package:rad_emigrate/features/consultation/presentation/providers/consultation_draft_provider.dart';
import 'package:rad_emigrate/features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import 'package:rad_emigrate/features/booking/data/booking_repository.dart';
import 'package:rad_emigrate/features/booking/domain/entities/service_booking.dart';
import 'package:rad_emigrate/features/booking/presentation/providers/booking_controller.dart';
import 'package:rad_emigrate/features/interviews/data/appointment_repository.dart';
import 'package:rad_emigrate/features/interviews/domain/entities/interview_appointment.dart';
import 'package:rad_emigrate/features/interviews/presentation/providers/appointment_controller.dart';
import 'package:rad_emigrate/features/visa/data/canonical_pathway_repository.dart';
import 'package:rad_emigrate/features/visa/data/visa_search_repository.dart';
import 'package:rad_emigrate/features/visa/data/fx_repository.dart';
import 'package:rad_emigrate/features/visa/domain/entities/canonical_pathway_entities.dart';
import 'package:rad_emigrate/features/visa/domain/entities/fx_rate.dart';
import 'package:rad_emigrate/features/visa/domain/entities/search_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/canonical_pathway_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

const ownerA = 'a1111111-1111-4111-8111-111111111111';
const ownerB = 'b1111111-1111-4111-8111-111111111111';
const receipt = 'c1111111-1111-4111-8111-111111111111';

class _Service implements SupabaseClientService {
  _Service(this.client);
  @override
  final SupabaseClient client;
  @override
  bool get isInitialized => true;
  @override
  Object? initializationError;
  @override
  Future<bool> initialize() async => true;
}

class _AuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Bookings implements BookingRepository {
  final pending = <Completer<List<BookingRecord>>>[];
  @override
  Future<List<BookingRecord>> listMyBookings() {
    final value = Completer<List<BookingRecord>>();
    pending.add(value);
    return value.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Appointments implements AppointmentRepository {
  final pending = <Completer<AppointmentListResult>>[];
  @override
  Future<AppointmentListResult> listMyAppointments() {
    final value = Completer<AppointmentListResult>();
    pending.add(value);
    return value.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sessions implements AiSessionRepository {
  final saved = <String>[];
  @override
  Future<List<AiSession>> listSessions(
    String userId, {
    String scope = 'user',
  }) async => [];
  @override
  Future<AiSession> createSession(
    String userId, {
    String scope = 'user',
  }) async => AiSession(
    id: receipt,
    userId: userId,
    questionCount: 0,
    createdAt: DateTime.utc(2026),
  );
  @override
  Future<void> saveMessage({
    required String sessionId,
    required String userId,
    required String role,
    required String content,
  }) async {
    saved.add('$role:$content');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedAi implements AiService {
  final pending = Completer<AiResponse>();
  @override
  bool get isAvailable => true;
  @override
  Future<AiResponse> complete(AiRequest request) => pending.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Service> _serviceWith(
  http.Response Function(http.Request) respond, {
  bool registerTeardown = true,
}) async {
  final client = SupabaseClient(
    'http://127.0.0.1:59999',
    'synthetic-local-only',
    httpClient: MockClient((request) async {
      final response = respond(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  String b64(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  // Synthetic JWT parsed locally only; never accepted by a real service.
  final token =
      '${b64({'alg': 'none'})}.${b64({'sub': ownerA, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.synthetic';
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'synthetic-refresh',
      'expires_in': 3600,
      'token_type': 'bearer',
      'user': {
        'id': ownerA,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
  if (registerTeardown) addTearDown(client.dispose);
  return _Service(client);
}

http.Response jsonResponse(Object? value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SDK logout clears identity while profile/auth mirror still holds A',
    () async {
      final service = await _serviceWith((request) => jsonResponse({}));
      final auth = AuthController(_AuthRepo())
        ..applySession(const UserSession(userId: ownerA, authenticated: true));
      final container = ProviderContainer(
        overrides: [
          supabaseClientServiceProvider.overrideWithValue(service),
          authControllerProvider.overrideWith((ref) => auth),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        authenticatedUserIdProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(supabaseAuthUserIdProvider.future);
      expect(container.read(authenticatedUserIdProvider), ownerA);
      await service.client.auth.signOut(scope: SignOutScope.local);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(auth.current.userId, ownerA);
      expect(container.read(authenticatedUserIdProvider), isNull);
    },
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'late AI reply from A is neither shown nor saved after switch to B',
    (tester) async {
      final auth = AuthController(_AuthRepo())
        ..applySession(const UserSession(userId: ownerA, authenticated: true));
      final sessions = _Sessions();
      final ai = _DelayedAi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => auth),
            aiServiceProvider.overrideWithValue(ai),
            aiSessionRepositoryProvider.overrideWithValue(sessions),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AiAssistantPage(),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.enterText(find.byType(TextField), 'A private question');
      await tester.tap(find.byTooltip('Send message'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(sessions.saved, contains('user:A private question'));
      auth.clearSession();
      await tester.pump();
      auth.applySession(const UserSession(userId: ownerB, authenticated: true));
      await tester.pump();
      ai.pending.complete(const AiResponse(text: 'A private delayed reply'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('A private delayed reply'), findsNothing);
      expect(sessions.saved.where((s) => s.startsWith('assistant:')), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'published UUID article renders full body and section without duplicate keys',
    (tester) async {
      final fixtures = (jsonDecode(
        File('supabase/contracts/fixtures/rad_v1_synthetic.json')
            .readAsStringSync(),
      ) as List).cast<Map>();
      final article = fixtures.firstWhere(
        (f) => f['name'] == 'get_visa_article',
      )['response'];
      final section = article['data']['sections'][0];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publishedVisaArticleProvider((
              articleId: article['data']['id'] as String,
              requestedLocale: 'fa',
              resolvedLocale: 'fa',
            )).overrideWith(
              (ref) async => CanonicalPathwayArticle.fromJson(
                Map<String, dynamic>.from(article as Map),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CanonicalPathwayPage(
              countrySlug: '',
              pathwaySlug: '',
              articleId: article['data']['id'] as String,
              requestedLocale: 'fa',
              resolvedLocale: 'fa',
              initialSectionAnchor: section['id'] as String,
            ),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('alphabravo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'actual SDK AI default request satisfies required closed schema and UUIDs',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final service = await _serviceWith((request) {
        expect(request.headers['x-rad-contract-version'], '1');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        expect(request.headers['x-rad-request-key'], body['request_key']);
        return jsonResponse(validAiEnvelope());
      });
      final ai = SupabaseAiService(service);
      for (var i = 0; i < 20; i++) {
        final response = await ai.complete(
          const AiRequest(prompt: 'synthetic request'),
        );
        expect(response.errorCode, isNull);
        expect(response.uncertain, isTrue);
      }
      final registry = jsonDecode(
        File('supabase/contracts/rad_v1.json').readAsStringSync(),
      ) as Map;
      final schema = registry[r'$defs']['ai_orchestrator_request'] as Map;
      final required = (schema['required'] as List).cast<String>().toSet();
      final allowed = (schema['properties'] as Map).keys.cast<String>().toSet();
      for (final body in bodies) {
        expect(body.keys.toSet().containsAll(required), isTrue);
        expect(allowed.containsAll(body.keys), isTrue);
        expect(
          body['request_key'],
          matches(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        );
        expect(body['context'], {
          'article_id': null,
          'section_id': null,
          'case_id': null,
        });
        expect(body['authorized_data_scopes'], isEmpty);
        expect(body['locale'], 'en');
        expect(body['guest_key'], isNull);
      }
      expect(bodies.map((b) => b['request_key']).toSet(), hasLength(20));
      final response = await ai.complete(
        const AiRequest(
          prompt: 'scoped',
          authorizedDataScopes: ['profile'],
          context: {'case_id': receipt},
          metadata: {'request_key': 'C1111111-1111-4111-8111-111111111111'},
        ),
      );
      expect(response.errorCode, isNull);
      expect(bodies.last['request_key'], receipt);
      expect(bodies.last['authorized_data_scopes'], ['profile']);
      expect((bodies.last['context'] as Map)['case_id'], receipt);
      File('build/rad_verified_ai_requests.json')
          .writeAsStringSync(jsonEncode(bodies));
    },
  );

  test('AI SDK sanitizes malformed/mismatched requests to maintain contract v1 validity', () async {
    final bodies = <Map<String, dynamic>>[];
    final service = await _serviceWith((request) {
      if (request.url.path.endsWith('ai-orchestrator')) {
        bodies.add((jsonDecode(request.body) as Map).cast<String, dynamic>());
        return jsonResponse(validAiEnvelope());
      }
      return jsonResponse({});
    });
    final ai = SupabaseAiService(service);

    final resp = await ai.complete(
      const AiRequest(
        prompt: 'test malformed parameters',
        conversationId: null,
        locale: 'fa_IR',
        authorizedDataScopes: [
          'unauthorized_privilege',
          'profile',
          'admin_bypass',
        ],
        context: {
          'article_id': 'malformed-article-slug',
          'section_id': '',
          'case_id': receipt,
        },
        metadata: {'guest_key': 'short'},
      ),
    );
    expect(resp.errorCode, isNull);
    expect(resp.uncertain, isTrue);

    final sent = bodies.last;
    expect(sent['session_id'], isNull);
    expect(sent['locale'], 'fa');
    expect(sent['guest_key'], isNull);
    expect(sent['authorized_data_scopes'], ['profile']);
    expect((sent['context'] as Map)['article_id'], isNull);
    expect((sent['context'] as Map)['section_id'], isNull);
    expect((sent['context'] as Map)['case_id'], receipt);

    final registry = jsonDecode(
      File('supabase/contracts/rad_v1.json').readAsStringSync(),
    ) as Map;
    final schema = registry[r'$defs']['ai_orchestrator_request'] as Map;
    final required = (schema['required'] as List).cast<String>().toSet();
    final allowed = (schema['properties'] as Map).keys.cast<String>().toSet();
    expect(sent.keys.toSet().containsAll(required), isTrue);
    expect(allowed.containsAll(sent.keys), isTrue);
  });

  test(
    'AI SDK handles Edge Function error responses safely and fails closed',
    () async {
      for (final errCase in [
        {'status': 422, 'code': 'invalid_request'},
        {'status': 429, 'code': 'daily_limit_reached'},
        {'status': 401, 'code': 'authentication_required'},
        {'status': 503, 'code': 'quota_check_failed'},
      ]) {
        final service = await _serviceWith((request) {
          return jsonResponse({
            'error': errCase['code'],
            'code': errCase['code'],
          }, errCase['status'] as int);
        });
        final ai = SupabaseAiService(service);
        final resp = await ai.complete(const AiRequest(prompt: 'error test'));
        expect(resp.uncertain, isTrue);
        expect(resp.errorCode, errCase['code']);
        expect(resp.text.isNotEmpty, isTrue);
      }
    },
  );

  test('booking accepts scalar server UUID only and never echoes unpersisted slots', () async {
    Object? reply = receipt;
    final service = await _serviceWith((request) {
      if (request.url.path == '/rest/v1/consultation_requests') {
        expect(request.url.queryParameters['id'], 'eq.$receipt');
        expect(request.url.queryParameters['user_id'], 'eq.$ownerA');
        return jsonResponse([
          {
            'id': receipt,
            'status': 'submitted',
            'created_at': '2026-01-01T00:00:00Z',
          },
        ]);
      }
      expect(request.url.path, '/rest/v1/rpc/submit_consultation_request');
      expect((jsonDecode(request.body) as Map).keys.toSet(), {
        'p_topic',
        'p_message',
      });
      return jsonResponse(reply);
    });
    final repo = SupabaseBookingRepository(service);
    const offering = ServiceOffering(
      id: 'consultation',
      slug: 'consultation',
      title: 'Synthetic intake',
      description: 'Synthetic',
      category: ServiceCategory.consultation,
      fulfillment: BookingFulfillment.humanConsultation,
    );
    final request = BookingRequest(
      serviceId: 'consultation',
      message: 'Synthetic',
      preferredStartUtc: DateTime.utc(2027),
      timeZoneId: 'Asia/Tehran',
    );
    final value = await repo
        .submitBooking(service: offering, request: request, locale: 'en')
        .catchError((Object error, StackTrace stack) {
          if (error is BookingException && error.cause != null) {
            Error.throwWithStackTrace(error.cause!, stack);
          }
          Error.throwWithStackTrace(error, stack);
        });
    expect(value.id, receipt);
    expect(value.createdAt, DateTime.utc(2026));
    expect(value.status, BookingStatus.submitted);
    expect(value.preferredStartUtc, isNull);
    expect(value.timeZoneId, isNull);
    for (final invalid in [
      null,
      '',
      'receipt-123',
      {'id': receipt},
      [receipt],
    ]) {
      reply = invalid;
      await expectLater(
        repo.submitBooking(service: offering, request: request, locale: 'en'),
        throwsA(isA<BookingException>()),
      );
    }
  });

  test('FX RPC cannot substitute a different currency pair', () async {
    final service = await _serviceWith(
      (request) => jsonResponse({
        'data': {
          'id': receipt,
          'provider': 'frankfurter',
          'base': 'USD',
          'quote': 'EUR',
          'rate': '0.123456789123456789',
          'observation_date': '2026-10-20',
          'fetched_at': '2026-10-20T10:00:00Z',
          'freshness_state': 'stale',
          'rate_basis': 'provider_reference',
          'source_url': 'https://api.frankfurter.dev/v1/latest',
        },
      }),
    );
    final repo = SupabaseFxRepository(service);
    await expectLater(
      repo.getQuote(base: 'EUR', quote: 'IRR'),
      throwsA(
        isA<FxQuoteUnavailableException>().having(
          (e) => e.message,
          'message',
          'fx_quote_pair_mismatch',
        ),
      ),
    );
    final quote = await repo.getQuote(base: 'USD', quote: 'EUR');
    expect(quote.toJson()['rate'], '0.123456789123456789');
  });

  test('FX rejects missing/unknown provenance and nonfinite rates', () {
    final valid = <String, dynamic>{
      'id': receipt,
      'provider': 'frankfurter',
      'base': 'USD',
      'quote': 'EUR',
      'rate': '0.91',
      'observation_date': '2026-10-20',
      'fetched_at': '2026-10-20T10:00:00Z',
      'freshness_state': 'stale',
      'rate_basis': 'provider_reference',
      'source_url': 'https://api.frankfurter.dev/v1/latest',
    };
    expect(FxRateQuote.fromJson(valid).freshnessState, FreshnessState.stale);
    expect(
      FxRateQuote.fromJson({...valid, 'rate': '0.123456789123456789'})
          .toJson()['rate'],
      '0.123456789123456789',
    );
    expect(() => FxRateQuote.fromJson({}), throwsFormatException);
    for (final key in valid.keys) {
      final missing = Map<String, dynamic>.from(valid)..remove(key);
      expect(
        () => FxRateQuote.fromJson(missing),
        throwsFormatException,
        reason: key,
      );
    }
    for (final invalid in [
      {'rate': 'NaN'},
      {'rate': 'Infinity'},
      {'rate': '-1'},
      {'rate': '1e-3'},
      {'id': 'unknown'},
      {'source_url': 'https:'},
      {'provider': 'unapproved'},
      {'rate_basis': 'free_market'},
      {'source_url': 'http://invalid.test'},
    ]) {
      expect(
        () => FxRateQuote.fromJson({...valid, ...invalid}),
        throwsFormatException,
      );
    }
  });

  test(
    'fact-check dates stay unknown when only modification timestamps exist',
    () {
      final source = OfficialSourceAttribution.fromJson({
        'authority_name': 'SYNTHETIC',
      });
      expect(source.lastFactCheckedAt, isNull);
      final article = CanonicalPathwayArticle.fromJson({
        'data': {
          'id': receipt,
          'title': 'SYNTHETIC',
          'sections': [],
          'updated_at': '2026-10-20T10:00:00Z',
        },
      });
      expect(article.lastFactCheckedAt, isNull);
      expect(article.factualStatus, FactualStatus.unverified);
    },
  );

  test('actual published search fixture opens UUID article and section through SDK', () async {
    final fixtures = (jsonDecode(
      File('supabase/contracts/fixtures/rad_v1_synthetic.json')
          .readAsStringSync(),
    ) as List).cast<Map>();
    final search = fixtures.firstWhere(
      (f) =>
          f['name'] == 'search_visa_articles' &&
          ((f['response']['data']['items']) as List).isNotEmpty,
    )['response'];
    final article = fixtures.firstWhere(
      (f) => f['name'] == 'get_visa_article',
    )['response'];
    final service = await _serviceWith((request) {
      if (request.url.path.endsWith('/search_visa_articles')) {
        return jsonResponse(search);
      }
      final args = jsonDecode(request.body) as Map;
      expect(
        (args['p_request']['selector'] as Map).keys,
        contains('article_id'),
      );
      return jsonResponse(article);
    });
    final result = await SupabaseVisaSearchRepository(service)
        .search(query: 'alphabravo');
    final hit = result.hits.first;
    final raw = (search['data']['items'] as List).first as Map;
    final target = raw['target'] as Map;
    final uri = Uri.parse(hit.deepLinkRoute);
    expect(uri.path, '/visa/articles/${target['id']}');
    expect(uri.queryParameters['section'], target['section_id']);
    expect(uri.fragment, raw['section_anchor']);
    final loaded = await SupabaseCanonicalPathwayRepository(service)
        .getArticleById(target['id'] as String);
    expect(loaded?.sections, isNotEmpty);
    expect(loaded?.sections.first.bodyMarkdown, contains('alphabravo'));
  });

  test(
    'mounted private selectors discard old account including late completions',
    () async {
      final auth = AuthController(_AuthRepo())
        ..applySession(const UserSession(userId: ownerA, authenticated: true));
      final books = _Bookings();
      final appointments = _Appointments();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => auth),
          bookingRepositoryProvider.overrideWithValue(books),
          appointmentRepositoryProvider.overrideWithValue(appointments),
        ],
      );
      addTearDown(container.dispose);
      final b = container.listen(currentBookingHistoryProvider, (_, _) {});
      final a = container.listen(currentAppointmentListProvider, (_, _) {});
      addTearDown(b.close);
      addTearDown(a.close);
      await container.pump();
      expect(books.pending, hasLength(1));
      expect(appointments.pending, hasLength(1));
      auth.clearSession();
      await container.pump();
      await container.read(bookingHistoryProvider(null).future);
      await container.read(appointmentListProvider(null).future);
      await container.pump();
      expect(
        container.read(currentBookingHistoryProvider).valueOrNull,
        isEmpty,
      );
      expect(
        container
            .read(currentAppointmentListProvider)
            .valueOrNull
            ?.appointments,
        isEmpty,
      );
      auth.applySession(const UserSession(userId: ownerB, authenticated: true));
      await container.pump();
      expect(books.pending, hasLength(2));
      expect(appointments.pending, hasLength(2));
      books.pending[1].complete([
        BookingRecord(
          id: ownerB,
          serviceId: 'synthetic',
          serviceTitle: 'B',
          status: BookingStatus.submitted,
          createdAt: DateTime.utc(2026),
        ),
      ]);
      appointments.pending[1].complete(
        AppointmentListResult(
          appointments: [
            InterviewAppointment(
              id: ownerB,
              kind: AppointmentKind.radSession,
              title: 'B',
              startUtc: DateTime.utc(2027),
              status: AppointmentStatus.requested,
              createdAt: DateTime.utc(2026),
            ),
          ],
          capability: AppointmentCapability.available,
        ),
      );
      await container.pump();
      books.pending[0].complete([
        BookingRecord(
          id: ownerA,
          serviceId: 'synthetic',
          serviceTitle: 'A private',
          status: BookingStatus.submitted,
          createdAt: DateTime.utc(2026),
        ),
      ]);
      appointments.pending[0].complete(
        AppointmentListResult(
          appointments: [
            InterviewAppointment(
              id: ownerA,
              kind: AppointmentKind.radSession,
              title: 'A private',
              startUtc: DateTime.utc(2027),
              status: AppointmentStatus.requested,
              createdAt: DateTime.utc(2026),
            ),
          ],
          capability: AppointmentCapability.available,
        ),
      );
      await container.pump();
      expect(
        container.read(currentBookingHistoryProvider).valueOrNull?.single.id,
        ownerB,
      );
      expect(
        container
            .read(currentAppointmentListProvider)
            .valueOrNull
            ?.appointments
            .single
            .id,
        ownerB,
      );
    },
  );

  test(
    'private AI and consultation drafts never transfer A/logout/B',
    () async {
      final auth = AuthController(_AuthRepo())
        ..applySession(const UserSession(userId: ownerA, authenticated: true));
      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith((ref) => auth)],
      );
      addTearDown(container.dispose);
      await container
          .read(aiPromptDraftProvider.notifier)
          .savePrompt('A private');
      await container
          .read(consultationDraftProvider.notifier)
          .updateDraft(message: 'A private');
      auth.clearSession();
      await container.pump();
      await container.read(aiPromptDraftProvider.notifier).ready;
      await container.read(consultationDraftProvider.notifier).ready;
      expect(container.read(aiPromptDraftProvider).hasContent, isFalse);
      expect(container.read(consultationDraftProvider).hasContent, isFalse);
      auth.applySession(const UserSession(userId: ownerB, authenticated: true));
      await container.pump();
      await container.read(aiPromptDraftProvider.notifier).ready;
      await container.read(consultationDraftProvider.notifier).ready;
      expect(container.read(aiPromptDraftProvider).hasContent, isFalse);
      expect(container.read(consultationDraftProvider).hasContent, isFalse);
    },
  );

  test(
    'unscoped legacy drafts are discarded without claiming an owner',
    () async {
      SharedPreferences.setMockInitialValues({
        'rad_ai_pending_prompt': 'unknown private owner',
      });
      final draft = AiPromptDraftNotifier();
      await draft.ready;
      expect(draft.state.hasContent, isFalse);
      draft.dispose();
    },
  );

  testWidgets(
    'mounted AI composer clears private A text on logout and B login',
    (tester) async {
      final auth = AuthController(_AuthRepo())
        ..applySession(const UserSession(userId: ownerA, authenticated: true));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith((ref) => auth)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AiAssistantPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'A private composer');
      await tester.pump();
      auth.clearSession();
      await tester.pump(const Duration(milliseconds: 100));
      auth.applySession(const UserSession(userId: ownerB, authenticated: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('A private composer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('UID-family refresh refetches held booking and appointment subscriptions after success and error', () async {
    final auth = AuthController(_AuthRepo())
      ..applySession(const UserSession(userId: ownerA, authenticated: true));
    final bookings = _Bookings();
    final appointments = _Appointments();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        bookingRepositoryProvider.overrideWithValue(bookings),
        appointmentRepositoryProvider.overrideWithValue(appointments),
      ],
    );
    addTearDown(container.dispose);
    final bs = container.listen(currentBookingHistoryProvider, (_, _) {});
    final aps = container.listen(currentAppointmentListProvider, (_, _) {});
    addTearDown(bs.close);
    addTearDown(aps.close);
    await container.pump();
    expect(bookings.pending, hasLength(1));
    expect(appointments.pending, hasLength(1));
    bookings.pending[0].completeError(StateError('synthetic failed fetch'));
    appointments.pending[0].completeError(StateError('synthetic failed fetch'));
    await container.pump();
    expect(container.read(currentBookingHistoryProvider).hasError, isTrue);
    expect(container.read(currentAppointmentListProvider).hasError, isTrue);
    container.invalidate(bookingHistoryProvider(ownerA));
    container.invalidate(appointmentListProvider(ownerA));
    await container.pump();
    expect(bookings.pending, hasLength(2));
    expect(appointments.pending, hasLength(2));
    bookings.pending[1].complete([]);
    appointments.pending[1].complete(
      const AppointmentListResult(
        appointments: [],
        capability: AppointmentCapability.available,
      ),
    );
    await container.pump();
    expect(container.read(currentBookingHistoryProvider).hasValue, isTrue);
    // Submit/reschedule/cancel use the same invalidation while their list is mounted.
    for (var i = 0; i < 3; i++) {
      container.invalidate(bookingHistoryProvider(ownerA));
      container.invalidate(appointmentListProvider(ownerA));
      await container.pump();
      expect(bookings.pending, hasLength(i + 3));
      expect(appointments.pending, hasLength(i + 3));
      bookings.pending.last.complete([]);
      appointments.pending.last.complete(
        const AppointmentListResult(
          appointments: [],
          capability: AppointmentCapability.available,
        ),
      );
      await container.pump();
    }
  });
}
