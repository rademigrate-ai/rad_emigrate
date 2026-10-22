import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rad_emigrate/core/services/ai/ai_request.dart';
import 'package:rad_emigrate/core/services/ai/supabase_ai_service.dart';
import 'package:rad_emigrate/features/admin/data/admin_cms_repository.dart';
import 'package:rad_emigrate/features/booking/data/booking_repository.dart';
import 'package:rad_emigrate/features/booking/domain/entities/service_booking.dart';

import 'package:rad_emigrate/features/visa/data/visa_search_repository.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/visa_search_controller.dart';

import '../support/mock_supabase_service.dart';
import '../support/rad_contract_fixtures.dart';

Map<String, dynamic> cmsRow(String locale, [String id = fixtureId]) => {
  'id': id,
  'slug': 'synthetic',
  'country_code': 'ZZ',
  'kind': 'related',
  'locale': locale,
  'title': 'Synthetic',
  'revision': 1,
  'editorial_state': 'draft',
  'verification_state': 'unverified',
  'updated_at': '2026-10-21T00:00:00Z',
};
const intake = ServiceOffering(
  id: 'built-in-consultation',
  slug: 'consultation',
  title: 'Synthetic intake',
  category: ServiceCategory.consultation,
  fulfillment: BookingFulfillment.humanConsultation,
);
Map<String, dynamic> proposalRow(String id) => {
  'id': id,
  'revision': 1,
  'target_article_id': fixtureId,
  'base_revision': 1,
  'old_snapshot_id': null,
  'new_snapshot_id': fixtureId,
  'authority_id': fixtureId,
  'changes': [],
  'evidence': [],
  'verification_state': 'unverified',
  'editorial_state': 'review',
  'created_at': '2026-10-21T00:00:00Z',
  'reviewed_at': null,
  'reviewed_by': null,
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('genuine closed empty search remains successful', () async {
    final fixtures = jsonDecode(
      File('supabase/contracts/fixtures/rad_v1_synthetic.json')
          .readAsStringSync(),
    ) as List;
    final response =
        (fixtures.firstWhere(
                  (f) => f['name'] == 'search_visa_articles',
                )['response']
                as Map)
            .cast<String, dynamic>();
    response['data'] = {...(response['data'] as Map), 'items': []};
    response['page'] = {'has_more': false, 'next_cursor': null};
    final service = await mockSupabaseService((r) async => rpcJson(response));
    expect(
      (await SupabaseVisaSearchRepository(
        service,
      ).search(query: 'Synthetic', locale: 'en')).hits,
      isEmpty,
    );
  });

  for (final status in [403, 503]) {
    test(
      'search distinguishes backend failure $status from genuine no results',
      () async {
        final service = await mockSupabaseService(
          (r) async => rpcJson({
            'code': 'PGRST202',
            'message': 'synthetic unavailable',
          }, status),
        );
        final notifier = VisaSearchNotifier(
          SupabaseVisaSearchRepository(service),
        );
        addTearDown(notifier.dispose);
        await notifier.search('Synthetic', locale: 'en');
        expect(notifier.state.result.hasError, true);
      },
    );
  }
  test('search rejects malformed supposedly verified search hits', () async {
    final service = await mockSupabaseService(
      (r) async => rpcJson({
        'data': {
          'items': [
            {'title': 'Synthetic', 'verification_state': 'verified'},
          ],
        },
      }),
    );
    final notifier = VisaSearchNotifier(SupabaseVisaSearchRepository(service));
    addTearDown(notifier.dispose);
    await notifier.search('Synthetic', locale: 'en');
    expect(notifier.state.result.hasError, true);
  });

  for (final proposals in [false, true]) {
    test('CMS bounds distinct nonempty pages, proposals=$proposals', () async {
      var calls = 0;
      final service = await mockSupabaseService((r) async {
        calls++;
        final locale =
            ((jsonDecode(r.body) as Map)['p_request'] as Map)['locale']
                as String? ??
            'en';
        final id =
            'c0000000-0000-4000-8000-${calls.toString().padLeft(12, '0')}';
        final item = proposals ? proposalRow(id) : cmsRow(locale, id);
        return rpcJson({
          'data': {
            'items': [item],
          },
          'meta': contractMeta(locale: locale),
          'page': {'has_more': true, 'next_cursor': 'cursor-$calls'},
        });
      });
      final repo = SupabaseAdminCmsRepository(service, maxPagesPerList: 3);
      await expectLater(
        proposals ? repo.listProposals() : repo.listCmsArticles(),
        throwsA(isA<CmsException>()),
      );
      expect(calls, 3);
    });
    test(
      'CMS rejects repeated records across pages, proposals=$proposals',
      () async {
        var calls = 0;
        final service = await mockSupabaseService((r) async {
          calls++;
          final locale =
              ((jsonDecode(r.body) as Map)['p_request'] as Map)['locale']
                  as String? ??
              'en';
          return rpcJson({
            'data': {
              'items': [proposals ? proposalRow(fixtureId) : cmsRow(locale)],
            },
            'meta': contractMeta(locale: locale),
            'page': {
              'has_more': calls == 1,
              'next_cursor': calls == 1 ? 'next' : null,
            },
          });
        });
        final repo = SupabaseAdminCmsRepository(service);
        await expectLater(
          proposals ? repo.listProposals() : repo.listCmsArticles(),
          throwsA(isA<CmsException>()),
        );
        expect(calls, 2);
      },
    );
  }
  test(
    'CMS identities are distinct per locale and a fresh listing resets cursors',
    () async {
      final service = await mockSupabaseService((r) async {
        final locale =
            ((jsonDecode(r.body) as Map)['p_request'] as Map)['locale']
                as String;
        return rpcJson({
          'data': {
            'items': [cmsRow(locale)],
          },
          'meta': contractMeta(locale: locale),
          'page': {'has_more': false, 'next_cursor': null},
        });
      });
      final repo = SupabaseAdminCmsRepository(service);
      expect((await repo.listCmsArticles()).map((r) => r.locale), ['fa', 'en']);
      expect(await repo.listCmsArticles(), hasLength(2));
    },
  );
  test(
    'CMS rejects an item that disagrees with its requested locale',
    () async {
      final service = await mockSupabaseService(
        (r) async => rpcJson({
          'data': {
            'items': [cmsRow('en')],
          },
          'meta': contractMeta(locale: 'fa'),
          'page': {'has_more': false, 'next_cursor': null},
        }),
      );
      await expectLater(
        SupabaseAdminCmsRepository(service).listCmsArticles(),
        throwsA(isA<CmsException>()),
      );
    },
  );
  test(
    'ordinary same-owner token refresh does not discard the pending AI reply',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      late MockSupabaseService service;
      service = await mockSupabaseService((r) {
        if (r.url.path.contains('/functions/')) {
          started.complete();
          return pending.future;
        }
        return Future.value(
          rpcJson(service.client.auth.currentSession!.toJson()),
        );
      });
      final result = SupabaseAiService(service)
          .complete(const AiRequest(prompt: 'Synthetic', locale: 'en'));
      await started.future;
      await service.client.auth.refreshSession();
      pending.complete(rpcJson(validAiEnvelope()));
      expect((await result).errorCode, isNull);
    },
  );
  test(
    'guest login then logout invalidates an earlier guest AI response',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final service = await mockSupabaseService((r) {
        if (r.url.path.contains('/functions/')) {
          started.complete();
          return pending.future;
        }
        return Future.value(rpcJson({}));
      });
      final saved = jsonEncode(service.client.auth.currentSession!.toJson());
      await service.client.auth.signOut(scope: SignOutScope.local);
      final result = SupabaseAiService(service).complete(
        const AiRequest(
          prompt: 'Synthetic guest',
          locale: 'en',
          metadata: {'guest_key': 'synthetic-guest-key-only'},
        ),
      );
      await started.future;
      await service.client.auth.recoverSession(saved);
      await service.client.auth.signOut(scope: SignOutScope.local);
      pending.complete(rpcJson(validAiEnvelope()));
      expect((await result).errorCode, 'session_changed');
    },
  );
  for (final invalid in [
    <String, dynamic>{},
    {
      'id': 'wrong-id',
      'status': 'submitted',
      'created_at': '2026-01-01T00:00:00Z',
    },
    {
      'id': fixtureId,
      'status': 'invented',
      'created_at': '2026-01-01T00:00:00Z',
    },
    {
      'id': fixtureId,
      'status': 'submitted',
      'created_at': '2026-02-30T00:00:00Z',
    },
  ]) {
    test('consultation receipt readback is fail closed: $invalid', () async {
      final service = await mockSupabaseService(
        (r) async => r.url.path.endsWith('/submit_consultation_request')
            ? rpcJson(fixtureId)
            : rpcJson(invalid.isEmpty ? [] : [invalid]),
      );
      await expectLater(
        SupabaseBookingRepository(service).submitBooking(
          service: intake,
          request: const BookingRequest(
            serviceId: 'built-in-consultation',
            message: 'Synthetic',
          ),
          locale: 'en',
        ),
        throwsA(isA<BookingException>()),
      );
    });
  }

  test('CMS rejects endless distinct empty cursors explicitly', () async {
    var calls = 0;
    final service = await mockSupabaseService((r) async {
      calls++;
      if (calls > 3) {
        return rpcJson({'code': 'XX000', 'message': 'test watchdog'}, 500);
      }
      final locale =
          ((jsonDecode(r.body) as Map)['p_request'] as Map)['locale'] as String;
      return rpcJson({
        'data': {'items': []},
        'meta': contractMeta(locale: locale),
        'page': {'has_more': true, 'next_cursor': 'unique-$calls'},
      });
    });
    await expectLater(
      SupabaseAdminCmsRepository(service).listCmsArticles(),
      throwsA(isA<CmsException>().having((e) => e.code, 'code', 'malformed')),
    );
    expect(calls, 1);
  });
  test('CMS rejects duplicate identities in a page instead of duplicating editable rows', () async {
    final service = await mockSupabaseService((r) async {
      final locale =
          ((jsonDecode(r.body) as Map)['p_request'] as Map)['locale'] as String;
      return rpcJson({
        'data': {
          'items': [cmsRow(locale), cmsRow(locale)],
        },
        'meta': contractMeta(locale: locale),
        'page': {'has_more': false, 'next_cursor': null},
      });
    });
    await expectLater(
      SupabaseAdminCmsRepository(service).listCmsArticles(),
      throwsA(isA<CmsException>()),
    );
  });
  for (final status in [200, 503]) {
    test(
      'AI invalidates A logout then A login while the old request is pending ($status)',
      () async {
        final pending = Completer<http.Response>();
        final started = Completer<void>();
        final service = await mockSupabaseService((r) {
          if (r.url.path.contains('/functions/')) {
            started.complete();
            return pending.future;
          }
          return Future.value(rpcJson({}));
        });
        final saved = jsonEncode(service.client.auth.currentSession!.toJson());
        final result = SupabaseAiService(service).complete(
          const AiRequest(
            prompt: 'Synthetic private request',
            locale: 'en',
            conversationId: fixtureId,
          ),
        );
        await started.future;
        await service.client.auth.signOut(scope: SignOutScope.local);
        await service.client.auth.recoverSession(saved);
        await Future<void>.delayed(Duration.zero);
        pending.complete(
          rpcJson(
            status == 200 ? validAiEnvelope() : {'code': 'old_owner_error'},
            status,
          ),
        );
        final response = await result;
        expect(response.errorCode, 'session_changed');
        expect(response.conversationId, isNull);
        expect(response.sources, isEmpty);
      },
    );
  }
  test('consultation receipt uses the persisted server timestamp, not the local clock', () async {
    var reads = 0;
    final service = await mockSupabaseService((r) async {
      if (r.url.path.endsWith('/submit_consultation_request')) {
        return rpcJson(fixtureId);
      }
      expect(r.url.path, '/rest/v1/consultation_requests');
      expect(r.url.queryParameters['id'], 'eq.$fixtureId');
      expect(r.url.queryParameters['user_id'], 'eq.$testOwner');
      reads++;
      return rpcJson([
        {
          'id': fixtureId,
          'status': 'submitted',
          'created_at': '2026-01-01T00:00:00+00:00',
        },
      ]);
    });
    final receipt = await SupabaseBookingRepository(service).submitBooking(
      service: intake,
      request: const BookingRequest(
        serviceId: 'built-in-consultation',
        message: 'Synthetic',
      ),
      locale: 'en',
    );
    expect(receipt.createdAt, DateTime.utc(2026));
    expect(reads, 1);
  });
}
