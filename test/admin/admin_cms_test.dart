import 'dart:convert';

import 'package:rad_emigrate/l10n/app_localizations.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/admin/data/admin_cms_repository.dart';
import 'package:rad_emigrate/features/admin/domain/entities/admin_cms_entities.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_cms_canonical_editor_page.dart';

import '../support/mock_supabase_service.dart';
import '../support/rad_contract_fixtures.dart';

Map<String, dynamic> draftResponse({String id = fixtureId}) => {
  'data': {
    'revision_id': fixtureId,
    'revision': 7,
    'editorial_state': 'draft',
    'verification_state': 'unverified',
    'updated_at': '2026-10-21T00:00:00Z',
    'content': {
      'article_id': id,
      'locale': 'en',
      'expected_revision': 7,
      'title': 'Synthetic draft',
      'summary': 'No immigration claims',
      'sections': [
        {
          'id': fixtureId,
          'anchor': 'synthetic',
          'heading': 'Synthetic',
          'order': 0,
          'blocks': [],
          'evidence_refs': [
            {
              'snapshot_id': fixtureId,
              'claim_id': null,
              'excerpt': 'Synthetic excerpt',
              'locator': null,
            },
          ],
        },
      ],
      'related_article_ids': [fixtureId],
      'merge_manifest_id': fixtureId,
    },
  },
  'meta': contractMeta(),
};
Map<String, dynamic> revisionAck({String id = fixtureId, int revision = 8}) => {
  'data': {
    'article_id': id,
    'revision_id': fixtureId,
    'revision': revision,
    'content_hash': 'a' * 64,
    'editorial_state': 'draft',
    'verification_state': 'unverified',
    'updated_at': '2026-10-21T00:00:00Z',
  },
  'meta': contractMeta(),
};
Map<String, dynamic> proposal({int revision = 4, String state = 'review'}) => {
  'id': fixtureId,
  'revision': revision,
  'target_article_id': fixtureId,
  'base_revision': 7,
  'old_snapshot_id': null,
  'new_snapshot_id': fixtureId,
  'authority_id': fixtureId,
  'changes': [],
  'evidence': [],
  'verification_state': 'unverified',
  'editorial_state': state,
  'created_at': '2026-10-21T00:00:00Z',
  'reviewed_at': null,
  'reviewed_by': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'uninitialized CMS never supplies fictional content or success',
    () async {
      final repo = SupabaseAdminCmsRepository(SupabaseClientService.instance);
      await expectLater(repo.listCmsArticles(), throwsA(isA<CmsException>()));
      await expectLater(repo.listProposals(), throwsA(isA<CmsException>()));
      await expectLater(
        repo.reviewProposal(
          proposalId: fixtureId,
          expectedRevision: 4,
          decision: SourceProposalReviewStatus.approved,
        ),
        throwsA(isA<CmsException>()),
      );
    },
  );
  test('CMS list parses closed envelopes and explicit empty results for both locales', () async {
    final seen = <String>[];
    final service = await mockSupabaseService((r) async {
      final request = (jsonDecode(r.body) as Map)['p_request'] as Map;
      seen.add(request['locale'] as String);
      return rpcJson({
        'data': {'items': []},
        'meta': contractMeta(locale: request['locale'] as String),
        'page': {'has_more': false, 'next_cursor': null},
      });
    });
    expect(
      await SupabaseAdminCmsRepository(service).listCmsArticles(),
      isEmpty,
    );
    expect(seen, ['fa', 'en']);
  });
  for (final status in [401, 403, 409, 404, 503]) {
    test('CMS read/write failure $status never acknowledges success', () async {
      final service = await mockSupabaseService(
        (r) async => r.url.path.endsWith('get_cms_article_draft')
            ? rpcJson(draftResponse())
            : rpcJson({
                'code': status == 409
                    ? 'PT409'
                    : status == 404
                    ? 'PGRST202'
                    : 'PT$status',
                'message': 'synthetic failure',
              }, status),
      );
      final repo = SupabaseAdminCmsRepository(service);
      final draft = await repo.getArticleDraft(fixtureId, locale: 'en');
      await expectLater(
        repo.saveCanonicalArticle(
          draft,
          title: 'Changed',
          summary: '',
          requestKey: fixtureId,
        ),
        throwsA(isA<CmsException>()),
      );
      await expectLater(
        repo.reviewProposal(
          proposalId: fixtureId,
          expectedRevision: 4,
          decision: SourceProposalReviewStatus.rejected,
        ),
        throwsA(isA<CmsException>()),
      );
      await expectLater(repo.listProposals(), throwsA(isA<CmsException>()));
    });
  }
  test('lossless draft save uses selected identity, real revision, locale and evidence', () async {
    Map? saved;
    final service = await mockSupabaseService((r) async {
      final request = (jsonDecode(r.body) as Map)['p_request'];
      if (r.url.path.endsWith('get_cms_article_draft')) {
        expect(request, {'article_id': fixtureId, 'locale': 'en'});
        return rpcJson(draftResponse());
      }
      saved = request as Map;
      return rpcJson(revisionAck());
    });
    final repo = SupabaseAdminCmsRepository(service);
    final draft = await repo.getArticleDraft(fixtureId, locale: 'en');
    expect(
      await repo.saveCanonicalArticle(
        draft,
        title: 'Changed title',
        summary: '',
        requestKey: fixtureId,
      ),
      isTrue,
    );
    final original = (draftResponse()['data'] as Map)['content'] as Map;
    expect(saved!['article_id'], fixtureId);
    expect(saved!['expected_revision'], 7);
    expect(saved!['locale'], 'en');
    for (final field in [
      'sections',
      'related_article_ids',
      'merge_manifest_id',
    ]) {
      expect(saved![field], original[field]);
    }
    expect(saved!.containsKey('editorial_state'), isFalse);
  });
  for (final mutation in [
    'missing_ack',
    'wrong_id',
    'wrong_revision',
    'wrong_locale',
    'bad_evidence',
  ]) {
    test('CMS rejects $mutation', () async {
      final service = await mockSupabaseService((r) async {
        if (r.url.path.endsWith('get_cms_article_draft')) {
          final value = draftResponse();
          if (mutation == 'wrong_id') {
            ((value['data'] as Map)['content'] as Map)['article_id'] =
                testOwner;
          }
          if (mutation == 'wrong_locale') {
            ((value['data'] as Map)['content'] as Map)['locale'] = 'fa';
          }
          if (mutation == 'bad_evidence') {
            (((value['data'] as Map)['content'] as Map)['sections'] as List)
                .first['evidence_refs'] = [
              {'snapshot_id': 'invented'},
            ];
          }
          return rpcJson(value);
        }
        return rpcJson(
          mutation == 'missing_ack' ? {} : revisionAck(revision: 99),
        );
      });
      final repo = SupabaseAdminCmsRepository(service);
      if (['wrong_id', 'wrong_locale', 'bad_evidence'].contains(mutation)) {
        await expectLater(
          repo.getArticleDraft(fixtureId, locale: 'en'),
          throwsA(isA<CmsException>()),
        );
      } else {
        final draft = await repo.getArticleDraft(fixtureId, locale: 'en');
        await expectLater(
          repo.saveCanonicalArticle(
            draft,
            title: 'Edited',
            summary: '',
            requestKey: fixtureId,
          ),
          throwsA(isA<CmsException>()),
        );
      }
    });
  }
  test('proposal requests use correct envelope and optimistic revision; review only creates draft', () async {
    final service = await mockSupabaseService((r) async {
      final req = (jsonDecode(r.body) as Map)['p_request'] as Map;
      if (r.url.path.endsWith('list_research_proposals')) {
        expect(req.keys.toSet(), {
          'article_id',
          'editorial_state',
          'verification_state',
          'cursor',
          'limit',
        });
        return rpcJson({
          'data': {
            'items': [proposal()],
          },
          'meta': contractMeta(),
          'page': {'has_more': false, 'next_cursor': null},
        });
      }
      expect(req['expected_revision'], 4);
      expect(req['decision'], 'accept');
      expect(req['request_key'], matches(r'^[0-9a-f-]{36}$'));
      return rpcJson({
        'data': {
          'proposal': proposal(revision: 5, state: 'approved'),
          'draft_revision': revisionAck()['data'],
        },
        'meta': contractMeta(),
      });
    });
    final repo = SupabaseAdminCmsRepository(service);
    final proposals = await repo.listProposals();
    expect(proposals.single.revision, 4);
    expect(proposals.single.factualStatus.name, 'unverified');
    expect(
      await repo.reviewProposal(
        proposalId: fixtureId,
        expectedRevision: 4,
        decision: SourceProposalReviewStatus.approved,
      ),
      isTrue,
    );
  });
  test('CMS drops late response after SDK logout', () async {
    late MockSupabaseService service;
    service = await mockSupabaseService((r) async {
      await service.client.auth.signOut(scope: SignOutScope.local);
      return rpcJson(draftResponse());
    });
    await expectLater(
      SupabaseAdminCmsRepository(service)
          .getArticleDraft(fixtureId, locale: 'en'),
      throwsA(isA<CmsException>()),
    );
  });
  test(
    'CMS request timeout and malformed lists never acquire fixtures',
    () async {
      final delayed = await mockSupabaseService((r) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return rpcJson({});
      });
      await expectLater(
        SupabaseAdminCmsRepository(
          delayed,
          timeout: const Duration(milliseconds: 1),
        ).listCmsArticles(),
        throwsA(isA<CmsException>()),
      );
      for (final body in [
        [],
        {},
        {
          'data': {'items': []},
          'meta': {},
        },
      ]) {
        final service = await mockSupabaseService((r) async => rpcJson(body));
        await expectLater(
          SupabaseAdminCmsRepository(service).listCmsArticles(),
          throwsA(isA<CmsException>()),
        );
        await expectLater(
          SupabaseAdminCmsRepository(service).listProposals(),
          throwsA(isA<CmsException>()),
        );
      }
    },
  );
  testWidgets('selected editor keeps unsaved text and reports failed save', (
    tester,
  ) async {
    final service = await tester.runAsync(
      () => mockSupabaseService(
        (r) async => r.url.path.endsWith('get_cms_article_draft')
            ? rpcJson(draftResponse())
            : rpcJson({'code': 'PT409', 'message': 'revision_conflict'}, 409),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminCmsRepositoryProvider.overrideWithValue(
            SupabaseAdminCmsRepository(service!),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminCmsCanonicalEditorPage(articleId: fixtureId, locale: 'en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('نسخه 7'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('cms-title')), 'Unsaved title');
    await tester.tap(find.text('ذخیره پیش‌نویس'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved title'), findsOneWidget);
    expect(find.byKey(const Key('cms-error')), findsOneWidget);
    expect(find.textContaining('پیش‌نویس ذخیره شد'), findsNothing);
  });
}
