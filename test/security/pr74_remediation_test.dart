import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/features/visa/presentation/visa_routes.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/visa_catalog_provider.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/routing/auth_redirect.dart';
import 'package:rad_emigrate/core/services/ai/ai_request.dart';
import 'package:rad_emigrate/core/services/ai/supabase_ai_service.dart';
import 'package:rad_emigrate/core/supabase/rad_contract.dart';
import 'package:rad_emigrate/core/supabase/rad_contract_schemas.dart';
import 'package:rad_emigrate/features/cost_calculator/domain/fee_parsing.dart';
import 'package:rad_emigrate/features/interview_scheduling/data/interview_repository.dart';
import 'package:rad_emigrate/features/visa/data/visa_search_repository.dart';
import 'package:rad_emigrate/features/visa/data/canonical_pathway_repository.dart';

import '../support/mock_supabase_service.dart';
import '../support/rad_contract_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generated client schemas match approved registry exactly', () {
    final definitions =
        (jsonDecode(File('supabase/contracts/rad_v1.json').readAsStringSync())
                as Map)[r'$defs']
            as Map;
    for (final name in radContractSchemas.keys) {
      expect(radContractSchemas[name], definitions[name], reason: name);
    }
  });
  for (final entry in {
    r'CA$150': 'CAD',
    r'A$150': 'AUD',
    r'CAD $150': 'CAD',
    r'US$150': 'USD',
    r'AUD $150': 'AUD',
    '150 EUR': 'EUR',
    '€150': 'EUR',
  }.entries) {
    test('single fee expression ${entry.key} retains ${entry.value}', () {
      final amount = parsePublishedAmount(entry.key);
      expect(amount, isNotNull);
      expect(amount!.currency, entry.value);
      expect(amount.amountMinor, 15000);
    });
  }
  for (final raw in [
    '2026 fee: USD 150',
    'USD 100 plus EUR 50',
    'CAD ?150',
    r'CAD A$150',
    'USD 100 200',
    'USD 1,23',
    'EUR 1.234,56',
    'USD -150',
    r'$20 per document',
    'about CAD 150',
    'USD 150.999',
    'USD ١٥٠',
  ]) {
    test(
      'ambiguous/unsupported fee is preserved as prose: $raw',
      () => expect(parsePublishedAmount(raw), isNull),
    );
  }
  for (final path in [
    '/booking/service/consultation',
    '/booking/service/b1111111-1111-4111-8111-111111111111',
    '/interviews',
    '/interview-scheduling',
  ]) {
    test('login/profile completion preserves legitimate destination $path', () {
      expect(restoredProtectedDestination(path), path);
      expect(
        authRedirect(
          uri: Uri(path: '/login', queryParameters: {'from': path}),
          isRestoring: false,
          isAuthenticated: true,
          profileComplete: true,
        ),
        path,
      );
      final completion = authRedirect(
        uri: Uri(path: '/login', queryParameters: {'from': path}),
        isRestoring: false,
        isAuthenticated: true,
        profileComplete: false,
      );
      expect(Uri.parse(completion!).queryParameters['from'], path);
    });
  }
  for (final path in [
    'https://evil.invalid',
    '//evil.invalid',
    '/booking/service/../admin',
    r'/booking/service/\evil',
    '/booking/service/%2F%2Fevil',
    '/booking/service/%252Fevil',
    '/booking/service/a/b',
    '/interviews/../admin',
    '/documents/%0d%0aLocation:evil',
  ]) {
    test(
      'return destination rejects unsafe $path',
      () => expect(restoredProtectedDestination(path), '/dashboard'),
    );
  }
  final fields = (validAiEnvelope()['data'] as Map).keys.toList();
  for (final field in fields) {
    test(
      'SDK rejects response missing $field without rendering unverified text',
      () async {
        final envelope = validAiEnvelope();
        (envelope['data'] as Map).remove(field);
        final service = await mockSupabaseService(
          (r) async => rpcJson(envelope),
        );
        final response = await SupabaseAiService(service)
            .complete(const AiRequest(prompt: 'synthetic'));
        expect(response.errorCode, 'invalid_ai_response');
        expect(response.uncertain, isTrue);
        expect(response.text, isNot(contains('SYNTHETIC')));
      },
    );
  }
  for (final envelope in [
    <String, dynamic>{'reply': 'unsafe'},
    {
      'data': {'reply': 'unsafe'},
    },
    {'data': null, 'meta': contractMeta()},
    {...validAiEnvelope(), 'meta': {}},
    {...validAiEnvelope(), 'unexpected': 'field'},
  ]) {
    test(
      'closed AI envelope rejects partial response ${jsonEncode(envelope)}',
      () => expect(
        () => requireRadContract('ai_orchestrator_response', envelope),
        throwsFormatException,
      ),
    );
  }
  test('wrong boolean, evidence, citation, quota, tool and date types are rejected', () {
    final malformed = <String, Object?>{
      'uncertain': 'false',
      'refused': null,
      'evidence_state': 'certain',
      'citations': [
        {'url': 'javascript:bad'},
      ],
      'quota': {'remaining': -1, 'reset_at': null},
      'tool_outcomes': [
        {'name': 'x', 'status': 'ok', 'safe_code': null},
      ],
    };
    for (final entry in malformed.entries) {
      final e = validAiEnvelope();
      (e['data'] as Map)[entry.key] = entry.value;
      expect(
        () => requireRadContract('ai_orchestrator_response', e),
        throwsFormatException,
        reason: entry.key,
      );
    }
    final e = validAiEnvelope();
    (e['meta'] as Map)['server_time'] = '2026-02-31T00:00:00Z';
    expect(
      () => requireRadContract('ai_orchestrator_response', e),
      throwsFormatException,
    );
  });
  test(
    'valid AI response remains uncertain for stale or truncated evidence',
    () async {
      for (final state in ['sufficient', 'stale', 'unavailable']) {
        final e = validAiEnvelope();
        final data = e['data'] as Map;
        data['evidence_state'] = state;
        data['uncertain'] = false;
        data['truncated'] = state == 'sufficient';
        final service = await mockSupabaseService((r) async => rpcJson(e));
        final response = await SupabaseAiService(service)
            .complete(const AiRequest(prompt: 'synthetic'));
        expect(response.errorCode, isNull);
        expect(response.uncertain, isTrue);
      }
    },
  );
  test('English-only search fallback retains locale, UUID and section through article RPC', () async {
    final calls = <Map>[];
    final service = await mockSupabaseService((r) async {
      final request = (jsonDecode(r.body) as Map)['p_request'] as Map;
      calls.add(request);
      if (r.url.path.endsWith('search_visa_articles')) {
        return rpcJson({
          'data': {
            'items': [
              {
                'article_id': fixtureId,
                'title': 'Synthetic EN',
                'article_kind': 'related',
                'match_locale': 'en',
                'target': {
                  'kind': 'visa_article',
                  'id': fixtureId,
                  'section_id': fixtureId,
                },
                'section_anchor': 'synthetic',
              },
            ],
          },
        });
      }
      expect(request['locale'], 'en');
      return rpcJson({
        'data': {
          'id': fixtureId,
          'title': 'Synthetic EN',
          'locale': 'en',
          'sections': [],
          'verification_state': 'unverified',
          'editorial_state': 'published',
          'fact_checked_at': null,
        },
      });
    });
    final result = await SupabaseVisaSearchRepository(service)
        .search(query: 'synthetic', locale: 'fa');
    final hit = result.hits.single;
    expect(hit.requestedLocale, 'fa');
    expect(hit.resolvedLocale, 'en');
    final uri = Uri.parse(hit.deepLinkRoute);
    expect(uri.path, '/visa/articles/$fixtureId');
    expect(uri.queryParameters, {
      'locale': 'en',
      'requested_locale': 'fa',
      'section': fixtureId,
    });
    expect(uri.fragment, 'synthetic');
    final article = await SupabaseCanonicalPathwayRepository(service)
        .getArticleById(fixtureId, locale: uri.queryParameters['locale']!);
    expect(article!.id, fixtureId);
    expect(article.lastFactCheckedAt, isNull);
    expect(calls.first['locale'], 'fa');
    await SupabaseVisaSearchRepository(service)
        .search(query: 'synthetic', locale: 'en');
    expect(calls.last['locale'], 'en');
  });
  test('dormant interview adapter rejects missing/invented receipt values', () {
    for (final data in [
      {},
      {'id': fixtureId, 'slot_id': fixtureId, 'status': 'confirmed'},
      {
        'id': 'intv-pending',
        'slot_id': fixtureId,
        'start_utc': '2026-10-22T00:00:00Z',
        'created_at': '2026-10-21T00:00:00Z',
        'status': 'confirmed',
      },
    ]) {
      expect(
        () => parseInterviewReceipt({'data': data}, fixtureId),
        throwsFormatException,
      );
    }
    final receipt = parseInterviewReceipt({
      'data': {
        'id': fixtureId,
        'slot_id': fixtureId,
        'start_utc': '2026-10-22T00:00:00Z',
        'created_at': '2026-10-21T00:00:00Z',
        'status': 'pending_confirmation',
      },
    }, fixtureId);
    expect(receipt.id, fixtureId);
    expect(receipt.createdAtUtc, DateTime.utc(2026, 10, 21));
    expect(receipt.status, 'pending_confirmation');
  });
  testWidgets(
    'Persian app opens English-only search hit through real route and locale-keyed article provider',
    (tester) async {
      final fixtures = (jsonDecode(
        File('supabase/contracts/fixtures/rad_v1_synthetic.json')
            .readAsStringSync(),
      ) as List).cast<Map>();
      final article =
          fixtures.firstWhere(
                (f) => f['name'] == 'get_visa_article',
              )['response']
              as Map;
      final id = (article['data'] as Map)['id'] as String;
      final section =
          ((article['data'] as Map)['sections'] as List).first as Map;
      final fetchedLocales = <String>[];
      final service = await tester.runAsync(
        () => mockSupabaseService((r) async {
          final request = (jsonDecode(r.body) as Map)['p_request'] as Map;
          if (r.url.path.endsWith('search_visa_articles')) {
            return rpcJson({
              'data': {
                'items': [
                  {
                    'article_id': id,
                    'title': 'Synthetic English',
                    'article_kind': 'related',
                    'match_locale': 'en',
                    'target': {
                      'kind': 'visa_article',
                      'id': id,
                      'section_id': section['id'],
                    },
                    'section_anchor': section['anchor'],
                  },
                ],
              },
            });
          }
          fetchedLocales.add(request['locale'] as String);
          return rpcJson(article);
        }),
      );
      final result = await tester.runAsync(
        () =>
            SupabaseVisaSearchRepository(service!)
                .search(query: 'synthetic', locale: 'fa'),
      );
      final router = GoRouter(
        initialLocation: result!.hits.single.deepLinkRoute,
        routes: [visaRoute()],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientServiceProvider.overrideWithValue(service!),
            visaCatalogProvider('fa').overrideWith(
              (ref) async => const VisaCatalog(
                countries: [],
                categories: [],
                programs: [],
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('fa'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fetchedLocales, ['en']);
      expect(find.textContaining('alphabravo'), findsOneWidget);
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['requested_locale'],
        'fa',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
