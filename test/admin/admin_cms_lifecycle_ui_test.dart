import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/data/admin_cms_repository.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_cms_canonical_editor_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

import '../support/mock_supabase_service.dart';
import '../support/rad_contract_fixtures.dart';

const String testArticleId = 'a1111111-1111-4111-8111-111111111111';
const String testRevisionId = 'b1111111-1111-4111-8111-111111111111';
const String testUserId = 'c1111111-1111-4111-8111-111111111111';
const String testEventId = 'd1111111-1111-4111-8111-111111111111';
const String testContentHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> buildDraftResponse({
  String editorialState = 'draft',
  int revision = 7,
}) => {
  'data': {
    'revision_id': testRevisionId,
    'revision': revision,
    'editorial_state': editorialState,
    'verification_state': 'unverified',
    'updated_at': '2026-10-25T00:00:00Z',
    'content': {
      'article_id': testArticleId,
      'locale': 'fa',
      'expected_revision': revision,
      'title': 'عنوان پیش‌نویس اولیه',
      'summary': 'خلاصه پیش‌نویس برای آزمون سردبیری',
      'sections': [],
      'related_article_ids': [],
      'merge_manifest_id': 'f1111111-1111-4111-8111-111111111111',
    },
  },
  'meta': contractMeta(locale: 'fa'),
};

Map<String, dynamic> buildRevisionsListResponse({
  String editorialState = 'draft',
  int revision = 7,
}) => {
  'data': {
    'items': [
      {
        'revision_id': testRevisionId,
        'revision': revision,
        'locale': 'fa',
        'content_hash': testContentHash,
        'editorial_state': editorialState,
        'verification_state': 'unverified',
        'created_at': '2026-10-25T00:00:00Z',
        'created_by': testUserId,
        'reviewed_at': null,
        'reviewed_by': null,
        'reason': null,
      },
    ],
  },
  'page': {'has_more': false, 'next_cursor': null},
  'meta': contractMeta(locale: 'fa'),
};

void main() {
  Widget buildTestApp(SupabaseAdminCmsRepository repo) {
    return ProviderScope(
      overrides: [adminCmsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminCmsCanonicalEditorPage(
          articleId: testArticleId,
          locale: 'fa',
        ),
      ),
    );
  }

  group('F05: CMS Admin Explicit Lifecycle UI Actions', () {
    testWidgets('renders lifecycle panel with draft state and review actions', (
      tester,
    ) async {
      final service = await tester.runAsync(
        () => mockSupabaseService((r) async {
          if (r.url.path.endsWith('get_cms_article_draft')) {
            return rpcJson(buildDraftResponse(editorialState: 'draft'));
          }
          if (r.url.path.endsWith('list_visa_article_revisions')) {
            return rpcJson(buildRevisionsListResponse(editorialState: 'draft'));
          }
          return rpcJson({'code': 'PT404', 'message': 'not_found'}, 404);
        }),
      );

      await tester.pumpWidget(
        buildTestApp(SupabaseAdminCmsRepository(service!)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cms-lifecycle-panel')), findsOneWidget);
      expect(find.text('پیش‌نویس'), findsWidgets);
      expect(find.byKey(const Key('cms-save-button')), findsOneWidget);
      expect(find.byKey(const Key('cms-submit-review-button')), findsOneWidget);
      expect(find.byKey(const Key('cms-publish-button')), findsNothing);
    });

    testWidgets(
      'submit review triggers prompt dialog and sends valid RPC call',
      (tester) async {
        Map<String, dynamic>? capturedSubmitPayload;
        final service = await tester.runAsync(
          () => mockSupabaseService((r) async {
            if (r.url.path.endsWith('get_cms_article_draft')) {
              return rpcJson(buildDraftResponse(editorialState: 'draft'));
            }
            if (r.url.path.endsWith('list_visa_article_revisions')) {
              return rpcJson(
                buildRevisionsListResponse(editorialState: 'draft'),
              );
            }
            if (r.url.path.endsWith('submit_visa_article_review')) {
              capturedSubmitPayload =
                  jsonDecode(r.body) as Map<String, dynamic>;
              return rpcJson({
                'data': {
                  'article_id': testArticleId,
                  'revision_id': testRevisionId,
                  'revision': 7,
                  'content_hash': testContentHash,
                  'editorial_state': 'review',
                  'verification_state': 'unverified',
                  'updated_at': '2026-10-25T01:00:00Z',
                },
                'meta': contractMeta(locale: 'fa'),
              });
            }
            return rpcJson({'code': 'PT404', 'message': 'not_found'}, 404);
          }),
        );

        await tester.pumpWidget(
          buildTestApp(SupabaseAdminCmsRepository(service!)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('cms-submit-review-button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('cms-submit-review-dialog')),
          findsOneWidget,
        );

        await tester.tap(find.text('تأیید و ارسال'));
        await tester.pumpAndSettle();

        expect(capturedSubmitPayload, isNotNull);
        final pRequest =
            capturedSubmitPayload!['p_request'] as Map<String, dynamic>;
        expect(pRequest['article_id'], testArticleId);
        expect(pRequest['revision_id'], testRevisionId);
        expect(pRequest['expected_revision'], 7);
        expect(pRequest['content_hash'], testContentHash);
      },
    );

    testWidgets('inReview state displays Approve and Reject buttons', (
      tester,
    ) async {
      final service = await tester.runAsync(
        () => mockSupabaseService((r) async {
          if (r.url.path.endsWith('get_cms_article_draft')) {
            return rpcJson(buildDraftResponse(editorialState: 'review'));
          }
          if (r.url.path.endsWith('list_visa_article_revisions')) {
            return rpcJson(
              buildRevisionsListResponse(editorialState: 'review'),
            );
          }
          return rpcJson({'code': 'PT404', 'message': 'not_found'}, 404);
        }),
      );

      await tester.pumpWidget(
        buildTestApp(SupabaseAdminCmsRepository(service!)),
      );
      await tester.pumpAndSettle();

      expect(find.text('در حال بررسی سردبیری'), findsWidgets);
      expect(find.byKey(const Key('cms-approve-button')), findsOneWidget);
      expect(find.byKey(const Key('cms-reject-button')), findsOneWidget);
    });

    testWidgets('reject button enforces mandatory note before submission', (
      tester,
    ) async {
      Map<String, dynamic>? capturedRejectPayload;
      final service = await tester.runAsync(
        () => mockSupabaseService((r) async {
          if (r.url.path.endsWith('get_cms_article_draft')) {
            return rpcJson(buildDraftResponse(editorialState: 'review'));
          }
          if (r.url.path.endsWith('list_visa_article_revisions')) {
            return rpcJson(
              buildRevisionsListResponse(editorialState: 'review'),
            );
          }
          if (r.url.path.endsWith('reject_visa_article_revision')) {
            capturedRejectPayload = jsonDecode(r.body) as Map<String, dynamic>;
            return rpcJson({
              'data': {
                'article_id': testArticleId,
                'revision_id': testRevisionId,
                'revision': 7,
                'content_hash': testContentHash,
                'editorial_state': 'rejected',
                'verification_state': 'unverified',
                'updated_at': '2026-10-25T01:00:00Z',
              },
              'meta': contractMeta(locale: 'fa'),
            });
          }
          return rpcJson({'code': 'PT404', 'message': 'not_found'}, 404);
        }),
      );

      await tester.pumpWidget(
        buildTestApp(SupabaseAdminCmsRepository(service!)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cms-reject-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cms-reject-dialog')), findsOneWidget);

      final confirmBtn = tester.widget<FilledButton>(
        find.byKey(const Key('cms-reject-confirm-button')),
      );
      expect(confirmBtn.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('cms-reject-note-input')),
        'نیاز به بازنویسی بخش تمکن مالی دارد',
      );
      await tester.pumpAndSettle();

      final enabledBtn = tester.widget<FilledButton>(
        find.byKey(const Key('cms-reject-confirm-button')),
      );
      expect(enabledBtn.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('cms-reject-confirm-button')));
      await tester.pumpAndSettle();

      expect(capturedRejectPayload, isNotNull);
      final pRequest =
          capturedRejectPayload!['p_request'] as Map<String, dynamic>;
      expect(pRequest['note'], 'نیاز به بازنویسی بخش تمکن مالی دارد');
    });

    testWidgets(
      'approved state displays Publish button and confirms with modal',
      (tester) async {
        Map<String, dynamic>? capturedPublishPayload;
        final service = await tester.runAsync(
          () => mockSupabaseService((r) async {
            if (r.url.path.endsWith('get_cms_article_draft')) {
              return rpcJson(buildDraftResponse(editorialState: 'approved'));
            }
            if (r.url.path.endsWith('list_visa_article_revisions')) {
              return rpcJson(
                buildRevisionsListResponse(editorialState: 'approved'),
              );
            }
            if (r.url.path.endsWith('publish_visa_article_revision')) {
              capturedPublishPayload =
                  jsonDecode(r.body) as Map<String, dynamic>;
              return rpcJson({
                'data': {
                  'resource_id': testArticleId,
                  'revision_id': testRevisionId,
                  'revision': 7,
                  'event_id': testEventId,
                  'published_at': '2026-10-25T02:00:00Z',
                },
                'meta': contractMeta(locale: 'fa'),
              });
            }
            return rpcJson({'code': 'PT404', 'message': 'not_found'}, 404);
          }),
        );

        await tester.pumpWidget(
          buildTestApp(SupabaseAdminCmsRepository(service!)),
        );
        await tester.pumpAndSettle();

        expect(find.text('تأیید سردبیری'), findsWidgets);
        expect(find.byKey(const Key('cms-publish-button')), findsOneWidget);

        await tester.tap(find.byKey(const Key('cms-publish-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cms-publish-dialog')), findsOneWidget);
        expect(
          find.textContaining('شناسه نسخه: $testRevisionId'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('cms-publish-confirm-button')));
        await tester.pumpAndSettle();

        expect(capturedPublishPayload, isNotNull);
        final pRequest =
            capturedPublishPayload!['p_request'] as Map<String, dynamic>;
        expect(pRequest['article_id'], testArticleId);
        expect(pRequest['revision_id'], testRevisionId);
        expect(pRequest['content_hash'], testContentHash);
      },
    );
  });

  group('F06: CMS Editor Dirty-State Protection', () {
    testWidgets(
      'editing title shows unsaved changes banner and discard button restores text',
      (tester) async {
        final service = await tester.runAsync(
          () => mockSupabaseService((r) async {
            if (r.url.path.endsWith('get_cms_article_draft')) {
              return rpcJson(buildDraftResponse());
            }
            if (r.url.path.endsWith('list_visa_article_revisions')) {
              return rpcJson(buildRevisionsListResponse());
            }
            return rpcJson({'code': 'PT404', 'message': 'not_found'}, 404);
          }),
        );

        await tester.pumpWidget(
          buildTestApp(SupabaseAdminCmsRepository(service!)),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cms-unsaved-warning')), findsNothing);

        await tester.enterText(
          find.byKey(const Key('cms-title')),
          'عنوان ویرایش‌شده جدید',
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cms-unsaved-warning')), findsOneWidget);
        expect(
          find.text('تغییرات ذخیره‌نشده در ویرایشگر وجود دارد.'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('cms-discard-button')));
        await tester.pumpAndSettle();

        expect(find.text('عنوان پیش‌نویس اولیه'), findsOneWidget);
        expect(find.byKey(const Key('cms-unsaved-warning')), findsNothing);
      },
    );

    testWidgets(
      'submitting review while dirty displays dirty warning modal first',
      (tester) async {
        final service = await tester.runAsync(
          () => mockSupabaseService((r) async {
            if (r.url.path.endsWith('get_cms_article_draft')) {
              return rpcJson(buildDraftResponse());
            }
            if (r.url.path.endsWith('list_visa_article_revisions')) {
              return rpcJson(buildRevisionsListResponse());
            }
            return rpcJson({'code': 'PT404', 'message': 'not_found'}, 404);
          }),
        );

        await tester.pumpWidget(
          buildTestApp(SupabaseAdminCmsRepository(service!)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('cms-summary')),
          'خلاصه اصلاح‌شده جدید که ذخیره نشده',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('cms-submit-review-button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('cms-submit-dirty-dialog')),
          findsOneWidget,
        );
        expect(find.text('تغییرات ذخیره‌نشده وجود دارد'), findsOneWidget);
      },
    );

    testWidgets(
      'back navigation while dirty prompts confirmation dialog before exit',
      (tester) async {
        final service = await tester.runAsync(
          () => mockSupabaseService((r) async {
            if (r.url.path.endsWith('get_cms_article_draft')) {
              return rpcJson(buildDraftResponse());
            }
            if (r.url.path.endsWith('list_visa_article_revisions')) {
              return rpcJson(buildRevisionsListResponse());
            }
            return rpcJson({'code': 'PT404', 'message': 'not_found'}, 404);
          }),
        );

        await tester.pumpWidget(
          buildTestApp(SupabaseAdminCmsRepository(service!)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('cms-title')),
          'تغییر عنوان بدون ذخیره',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cms-discard-dialog')), findsOneWidget);
        expect(find.text('تغییرات ذخیره‌نشده'), findsOneWidget);

        await tester.tap(find.byKey(const Key('cms-discard-cancel')));
        await tester.pumpAndSettle();

        expect(find.text('تغییر عنوان بدون ذخیره'), findsOneWidget);
        expect(find.byKey(const Key('cms-discard-dialog')), findsNothing);
      },
    );
  });
}
