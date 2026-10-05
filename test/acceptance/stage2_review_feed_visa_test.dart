import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  final root = Directory.current.path;
  String read(String relative) => File('$root/$relative').readAsStringSync();

  group('Stage 2 review publish security', () {
    test('publish RPC is admin-gated and idempotent', () {
      final sql = read(
        'supabase/migrations/20261005120000_stage2_review_feed_publish.sql',
      );
      expect(sql.contains('publish_content_draft'), isTrue);
      expect(sql.contains("private.has_role(array['admin','super_admin'])"), isTrue);
      expect(sql.contains("raise exception 'forbidden'"), isTrue);
      expect(sql.contains("raise exception 'rejected draft cannot be published'"), isTrue);
      expect(sql.contains('Idempotent'), isTrue);
      expect(sql.contains('feed_item_localizations'), isTrue);
    });

    test('research worker never publishes feed', () {
      final worker = read('supabase/functions/research-sync/index.ts');
      expect(worker.contains('publish_content_draft'), isFalse);
      expect(worker.toLowerCase().contains('feed_items'), isFalse);
    });

    test('Stage 1 candidate path does not write feed', () {
      final stage1 = read(
        'supabase/migrations/20261005102000_stage1_ai_research_completion.sql',
      );
      final start = stage1.indexOf('create_research_review_candidate');
      final body = stage1.substring(start, start + 900);
      expect(body.contains('content_drafts'), isTrue);
      expect(body.contains('feed_items'), isFalse);
    });

    test('feed public RLS remains published-only', () {
      final feed = read(
        'supabase/migrations/20261003222909_project14_feed_notifications.sql',
      );
      expect(feed.contains('published feed public read'), isTrue);
      expect(feed.contains("status='published'"), isTrue);
      expect(feed.contains('admins manage feed'), isTrue);
    });
  });

  group('Stage 2 admin review UI wiring', () {
    test('review detail sheet and actions exist', () {
      final sheet = read(
        'lib/features/admin/presentation/pages/admin_review_detail_sheet.dart',
      );
      final actions = read(
        'lib/features/admin/data/admin_review_actions.dart',
      );
      final ops = read(
        'lib/features/admin/presentation/pages/admin_operations_page.dart',
      );
      final sections = read(
        'lib/features/admin/presentation/pages/admin_operations_sections.dart',
      );
      expect(sheet.contains('showAdminReviewDetail'), isTrue);
      expect(sheet.contains('publishExplicit'), isTrue);
      expect(sheet.contains('reject'), isTrue);
      expect(sheet.contains('keepPending'), isTrue);
      expect(sheet.contains('approve'), isTrue);
      expect(actions.contains('publish_content_draft'), isTrue);
      expect(actions.contains('set_content_draft_status'), isTrue);
      expect(actions.contains('update_content_draft'), isTrue);
      expect(ops.contains("part 'admin_operations_sections.dart'"), isTrue);
      expect(ops.contains('showAdminReviewDetail'), isTrue);
      expect(ops.contains('admin_review_detail_sheet.dart'), isTrue);
      expect(sections.contains('showAdminReviewDetail'), isTrue);
      expect(sections.contains('onTap: () => showAdminReviewDetail'), isTrue);
      expect(sections.contains('_Reviews'), isTrue);
      expect(sections.contains('_Sources'), isTrue);
      expect(sections.contains('_Research'), isTrue);
      expect(sections.contains('_Feed'), isTrue);
    });
  });

  group('Stage 2 visa structured content', () {
    test('visa steps migration seeds ordered steps without fabricating fees', () {
      final sql = read(
        'supabase/migrations/20261005130000_stage2_visa_structured_steps.sql',
      );
      expect(sql.contains('visa_program_steps'), isTrue);
      expect(sql.contains('study-canada'), isTrue);
      expect(sql.contains('work-germany'), isTrue);
      expect(sql.contains('25000'), isFalse);
      expect(sql.contains(r'$'), isFalse);
    });

    test('visa page uses localization facade not language ternaries', () {
      final page = read(
        'lib/features/visa/presentation/pages/visa_page.dart',
      );
      expect(page.contains("fa ? '"), isFalse);
      expect(page.contains('applicationSteps'), isTrue);
      expect(page.contains('structuredSourceNote'), isTrue);
    });
  });

  group('Stage 2 localization', () {
    test('Stage 2 keys non-empty and distinct in EN and FA', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final fa = lookupAppLocalizations(const Locale('fa'));
      final pairs = [
        (en.reviewQueueTitle, fa.reviewQueueTitle),
        (en.reject, fa.reject),
        (en.keepPending, fa.keepPending),
        (en.approve, fa.approve),
        (en.publishExplicit, fa.publishExplicit),
        (en.publishRequiresHuman, fa.publishRequiresHuman),
        (en.applicationSteps, fa.applicationSteps),
        (en.structuredSourceNote, fa.structuredSourceNote),
        (en.editTitle, fa.editTitle),
        (en.editBody, fa.editBody),
        (en.findingPublishNote, fa.findingPublishNote),
        (en.reviewDraftTitle, fa.reviewDraftTitle),
        (en.reviewFindingTitle, fa.reviewFindingTitle),
      ];
      for (final pair in pairs) {
        expect(pair.$1.trim().isNotEmpty, isTrue);
        expect(pair.$2.trim().isNotEmpty, isTrue);
        expect(pair.$2, isNot(pair.$1));
      }
    });
  });
}
