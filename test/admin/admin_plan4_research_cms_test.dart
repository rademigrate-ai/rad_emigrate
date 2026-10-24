import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/data/admin_cms_repository.dart';
import 'package:rad_emigrate/features/admin/domain/entities/admin_cms_entities.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_source_diff_page.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_source_monitor_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

import '../support/mock_supabase_service.dart';
import '../support/rad_contract_fixtures.dart';

const dummyHash =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> sampleRevisionResult({
  String articleId = fixtureId,
  String revisionId = fixtureId,
  int revision = 8,
  String state = 'review',
}) => {
  'data': {
    'article_id': articleId,
    'revision_id': revisionId,
    'revision': revision,
    'content_hash': dummyHash,
    'editorial_state': state,
    'verification_state': 'verified',
    'updated_at': '2026-10-24T12:00:00Z',
  },
  'meta': contractMeta(),
};

Map<String, dynamic> samplePublicationResult({
  String articleId = fixtureId,
  String revisionId = fixtureId,
  int revision = 8,
}) => {
  'data': {
    'resource_id': articleId,
    'revision_id': revisionId,
    'revision': revision,
    'event_id': fixtureId,
    'published_at': '2026-10-24T12:00:00Z',
    'target': {'kind': 'visa_article', 'id': articleId, 'section_id': null},
  },
  'meta': contractMeta(),
};

Map<String, dynamic> sampleRevisionSummary({
  String revisionId = fixtureId,
  int revision = 1,
  String state = 'published',
}) => {
  'revision_id': revisionId,
  'revision': revision,
  'locale': 'en',
  'content_hash': dummyHash,
  'editorial_state': state,
  'verification_state': 'verified',
  'created_at': '2026-10-24T10:00:00Z',
  'created_by': testOwner,
  'reviewed_at': '2026-10-24T11:00:00Z',
  'reviewed_by': testOwner,
  'reason': 'Official policy revision update',
};

Map<String, dynamic> sampleAuthority({
  String id = fixtureId,
  String name = 'Immigration Refugees and Citizenship Canada',
}) => {
  'id': id,
  'name': name,
  'authority_type': 'government',
  'country_code': 'CA',
  'jurisdiction': 'federal',
  'competence_topics': ['immigration', 'visa'],
  'official_domains': ['canada.ca', 'cic.gc.ca'],
  'verification_state': 'verified',
  'verification_revision': 1,
  'verified_at': '2026-10-24T00:00:00Z',
  'expires_at': '2027-10-24T00:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plan 4 CMS Revision Lifecycle Repository RPCs', () {
    test('submitArticleReview submits review request and returns ArticleRevisionResult', () async {
      Map? receivedRequest;
      final service = await mockSupabaseService((r) async {
        if (r.url.path.endsWith('submit_visa_article_review')) {
          receivedRequest = (jsonDecode(r.body) as Map)['p_request'] as Map;
          return rpcJson(sampleRevisionResult(state: 'review'));
        }
        return rpcJson({}, 404);
      });

      final repo = SupabaseAdminCmsRepository(service);
      final res = await repo.submitArticleReview(
        articleId: fixtureId,
        revisionId: fixtureId,
        expectedRevision: 7,
        contentHash: dummyHash,
        note: 'Ready for editorial review',
        requestKey: fixtureId,
      );

      expect(receivedRequest!['article_id'], fixtureId);
      expect(receivedRequest!['expected_revision'], 7);
      expect(receivedRequest!['content_hash'], dummyHash);
      expect(res.articleId, fixtureId);
      expect(res.revisionId, fixtureId);
      expect(res.editorialState, ArticleEditorialStatus.inReview);
    });

    test('approveArticleRevision approves revision and verifies editorialState is approved', () async {
      Map? receivedRequest;
      final service = await mockSupabaseService((r) async {
        if (r.url.path.endsWith('approve_visa_article_revision')) {
          receivedRequest = (jsonDecode(r.body) as Map)['p_request'] as Map;
          return rpcJson(sampleRevisionResult(state: 'approved'));
        }
        return rpcJson({}, 404);
      });

      final repo = SupabaseAdminCmsRepository(service);
      final res = await repo.approveArticleRevision(
        articleId: fixtureId,
        revisionId: fixtureId,
        expectedRevision: 7,
        contentHash: dummyHash,
        note: 'Approved after verification',
        requestKey: fixtureId,
      );

      expect(receivedRequest!['article_id'], fixtureId);
      expect(res.editorialState, ArticleEditorialStatus.approved);
    });

    test('rejectArticleRevision rejects revision safely', () async {
      Map? receivedRequest;
      final service = await mockSupabaseService((r) async {
        if (r.url.path.endsWith('reject_visa_article_revision')) {
          receivedRequest = (jsonDecode(r.body) as Map)['p_request'] as Map;
          return rpcJson(sampleRevisionResult(state: 'rejected'));
        }
        return rpcJson({}, 404);
      });

      final repo = SupabaseAdminCmsRepository(service);
      final res = await repo.rejectArticleRevision(
        articleId: fixtureId,
        revisionId: fixtureId,
        expectedRevision: 7,
        contentHash: dummyHash,
        note: 'Discrepancy found with official source',
        requestKey: fixtureId,
      );

      expect(
        receivedRequest!['note'],
        'Discrepancy found with official source',
      );
      expect(res.articleId, fixtureId);
    });

    test('publishArticleRevision publishes approved revision and returns PublicationResult', () async {
      Map? receivedRequest;
      final service = await mockSupabaseService((r) async {
        if (r.url.path.endsWith('publish_visa_article_revision')) {
          receivedRequest = (jsonDecode(r.body) as Map)['p_request'] as Map;
          return rpcJson(samplePublicationResult());
        }
        return rpcJson({}, 404);
      });

      final repo = SupabaseAdminCmsRepository(service);
      final res = await repo.publishArticleRevision(
        articleId: fixtureId,
        revisionId: fixtureId,
        contentHash: dummyHash,
        requestKey: fixtureId,
      );

      expect(receivedRequest!['revision_id'], fixtureId);
      expect(res.resourceId, fixtureId);
      expect(res.revision, 8);
      expect(res.target['kind'], 'visa_article');
    });

    test('rollbackArticle restores previous revision with reason', () async {
      Map? receivedRequest;
      final service = await mockSupabaseService((r) async {
        if (r.url.path.endsWith('rollback_visa_article')) {
          receivedRequest = (jsonDecode(r.body) as Map)['p_request'] as Map;
          return rpcJson(sampleRevisionResult(revision: 9, state: 'published'));
        }
        return rpcJson({}, 404);
      });

      final repo = SupabaseAdminCmsRepository(service);
      final res = await repo.rollbackArticle(
        articleId: fixtureId,
        locale: 'en',
        fromRevisionId: fixtureId,
        expectedRevision: 8,
        reason: 'Emergency rollback due to regulation freeze',
        requestKey: fixtureId,
      );

      expect(receivedRequest!['from_revision_id'], fixtureId);
      expect(
        receivedRequest!['reason'],
        'Emergency rollback due to regulation freeze',
      );
      expect(res.revision, 9);
    });

    test(
      'listArticleRevisions retrieves paginated list of revision summaries',
      () async {
        final service = await mockSupabaseService((r) async {
          if (r.url.path.endsWith('list_visa_article_revisions')) {
            return rpcJson({
              'data': {
                'items': [
                  sampleRevisionSummary(revision: 1),
                  sampleRevisionSummary(
                    revisionId: 'c2222222-2222-4222-8222-222222222222',
                    revision: 2,
                  ),
                ],
              },
              'meta': contractMeta(),
              'page': {'has_more': false, 'next_cursor': null},
            });
          }
          return rpcJson({}, 404);
        });

        final repo = SupabaseAdminCmsRepository(service);
        final items = await repo.listArticleRevisions(
          articleId: fixtureId,
          locale: 'en',
        );
        expect(items.length, 2);
        expect(items.first.revision, 1);
        expect(items.first.reason, 'Official policy revision update');
      },
    );
  });

  group('Plan 4 Official Authorities & Source Lifecycle RPCs', () {
    test('listOfficialAuthorities returns verified authorities', () async {
      final service = await mockSupabaseService((r) async {
        if (r.url.path.endsWith('list_official_authorities')) {
          return rpcJson({
            'data': {
              'items': [sampleAuthority()],
            },
            'meta': contractMeta(),
            'page': {'has_more': false, 'next_cursor': null},
          });
        }
        return rpcJson({}, 404);
      });

      final repo = SupabaseAdminCmsRepository(service);
      final items = await repo.listOfficialAuthorities();
      expect(items.length, 1);
      expect(items.first.name, 'Immigration Refugees and Citizenship Canada');
      expect(items.first.isVerified, isTrue);
      expect(items.first.officialDomains, contains('canada.ca'));
    });

    test('discoverOfficialAuthorities dispatches discovery job', () async {
      Map? receivedRequest;
      final service = await mockSupabaseService((r) async {
        if (r.url.path.endsWith('discover_official_authorities')) {
          receivedRequest = (jsonDecode(r.body) as Map)['p_request'] as Map;
          return rpcJson({
            'data': {
              'job_id': fixtureId,
              'status': 'queued',
              'deduplicated': false,
            },
            'meta': contractMeta(),
          });
        }
        return rpcJson({}, 404);
      });

      final repo = SupabaseAdminCmsRepository(service);
      final res = await repo.discoverOfficialAuthorities(
        countryCode: 'CA',
        topic: 'immigration',
        requestKey: fixtureId,
      );

      expect(receivedRequest!['country_code'], 'CA');
      expect(res['job_id'], fixtureId);
      expect(res['status'], 'queued');
    });

    test('enqueueResearchRefresh queues authority refresh job', () async {
      Map? receivedRequest;
      final service = await mockSupabaseService((r) async {
        if (r.url.path.endsWith('enqueue_research_refresh')) {
          receivedRequest = (jsonDecode(r.body) as Map)['p_request'] as Map;
          return rpcJson({
            'data': {
              'job_id': fixtureId,
              'status': 'queued',
              'deduplicated': true,
            },
            'meta': contractMeta(),
          });
        }
        return rpcJson({}, 404);
      });

      final repo = SupabaseAdminCmsRepository(service);
      final res = await repo.enqueueResearchRefresh(
        authorityIds: [fixtureId],
        requestKey: fixtureId,
      );

      expect(receivedRequest!['authority_ids'], [fixtureId]);
      expect(res['deduplicated'], isTrue);
    });

    test('approveVisaSourceInventory validates snapshot inventory', () async {
      Map? receivedRequest;
      final service = await mockSupabaseService((r) async {
        if (r.url.path.endsWith('approve_visa_source_inventory')) {
          receivedRequest = (jsonDecode(r.body) as Map)['p_request'] as Map;
          return rpcJson({
            'data': {
              'inventory_revision': 3,
              'inventory_hash': dummyHash,
              'source_snapshot_ids': [
                fixtureId,
                'c2222222-2222-4222-8222-222222222222',
              ],
            },
            'meta': contractMeta(),
          });
        }
        return rpcJson({}, 404);
      });

      final repo = SupabaseAdminCmsRepository(service);
      final res = await repo.approveVisaSourceInventory(
        articleId: fixtureId,
        sourceSnapshotIds: [fixtureId, 'c2222222-2222-4222-8222-222222222222'],
        expectedInventoryRevision: 2,
        requestKey: fixtureId,
      );

      expect(receivedRequest!['expected_inventory_revision'], 2);
      expect(res['inventory_revision'], 3);
      expect(res['inventory_hash'], dummyHash);
    });
  });

  group('Plan 4 Admin UI Widgets Verification', () {
    testWidgets(
      'AdminSourceDiffPage renders section diff tabs and human review disclaimer',
      (tester) async {
        final service = await tester.runAsync(
          () => mockSupabaseService((r) async {
            if (r.url.path.endsWith('get_research_proposal')) {
              return rpcJson({
                'data': {
                  'id': fixtureId,
                  'revision': 1,
                  'target_article_id': fixtureId,
                  'base_revision': 1,
                  'old_snapshot_id': null,
                  'new_snapshot_id': fixtureId,
                  'authority_id': fixtureId,
                  'changes': [
                    {
                      'section_id': fixtureId,
                      'operation': 'replace',
                      'before_hash': dummyHash,
                      'replacement': {
                        'id': fixtureId,
                        'anchor': 'eligibility-criteria',
                        'heading': 'شرایط جدید پذیرش ویزا',
                        'order': 1,
                        'blocks': [
                          {
                            'id': fixtureId,
                            'type': 'paragraph',
                            'text':
                                'حداقل تمکن مالی به ۱۰,۰۰۰ یورو افزایش یافت.',
                            'items': [],
                          },
                        ],
                        'evidence_refs': [],
                      },
                      'claim_ids': [fixtureId],
                    },
                  ],
                  'evidence': [
                    {
                      'source_document_id': fixtureId,
                      'snapshot_id': fixtureId,
                      'claim_id': null,
                      'section_id': null,
                      'url': 'https://canada.ca/immigration/rules',
                      'publisher': 'IRCC Canada',
                      'source_class': 'official_primary',
                      'authority_id': fixtureId,
                      'excerpt':
                          'Funds required for single applicant is updated.',
                      'locator': null,
                      'fetched_at': '2026-10-24T00:00:00Z',
                      'verified_at': '2026-10-24T00:00:00Z',
                      'fresh_until': '2027-10-24T00:00:00Z',
                      'verification_state': 'verified',
                      'freshness_state': 'fresh',
                    },
                  ],
                  'verification_state': 'verified',
                  'editorial_state': 'review',
                  'created_at': '2026-10-24T00:00:00Z',
                  'reviewed_at': null,
                  'reviewed_by': null,
                },
                'meta': contractMeta(),
              });
            }
            return rpcJson({}, 404);
          }),
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
              home: AdminSourceDiffPage(sourceId: fixtureId),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Section Diff is displayed
        expect(find.text('شرایط جدید پذیرش ویزا'), findsOneWidget);
        expect(find.text('جایگزینی محتوا'), findsOneWidget);
        expect(find.textContaining('حداقل تمکن مالی'), findsOneWidget);

        // Verify Safety Disclaimer is present
        expect(
          find.textContaining(
            'تأیید پیشنهاد صرفاً یک پیش‌نویس (Draft) غیرمنتشر در CMS ایجاد می‌کند',
          ),
          findsOneWidget,
        );

        // Switch to Evidence Tab
        await tester.tap(find.textContaining('شواهد و مدارک'));
        await tester.pumpAndSettle();

        expect(find.text('IRCC Canada'), findsNWidgets(2));
        expect(
          find.textContaining('Funds required for single applicant'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AdminSourceMonitorPage displays proposals and official authorities tab',
      (tester) async {
        final service = await tester.runAsync(
          () => mockSupabaseService((r) async {
            if (r.url.path.endsWith('list_research_proposals')) {
              return rpcJson({
                'data': {'items': []},
                'meta': contractMeta(),
                'page': {'has_more': false, 'next_cursor': null},
              });
            }
            if (r.url.path.endsWith('list_official_authorities')) {
              return rpcJson({
                'data': {
                  'items': [
                    sampleAuthority(name: 'German Federal Foreign Office'),
                  ],
                },
                'meta': contractMeta(),
                'page': {'has_more': false, 'next_cursor': null},
              });
            }
            return rpcJson({}, 404);
          }),
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
              home: AdminSourceMonitorPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Proposals empty state
        expect(find.text('هیچ تغییر جدیدی یافت نشد.'), findsOneWidget);

        // Switch to Authorities Tab
        await tester.tap(find.text('مراجع رسمی و معتبر'));
        await tester.pumpAndSettle();

        expect(find.text('German Federal Foreign Office'), findsOneWidget);
        expect(find.text('تأییدشده رسمی'), findsOneWidget);
        expect(find.text('واکشی تغییرات منبع'), findsOneWidget);
      },
    );
  });
}
