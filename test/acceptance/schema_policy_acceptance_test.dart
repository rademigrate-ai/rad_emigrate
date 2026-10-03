import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repository-level acceptance of production schema publish/review gates.
///
/// These assertions bind to checked-in SQL migrations (source of truth for RLS
/// and status machines) without inventing Flutter client APIs.
void main() {
  late String knowledgeSql;
  late String feedSql;
  late String aiSql;

  setUpAll(() {
    knowledgeSql = File(
      'supabase/migrations/20261003211500_project10_knowledge_research.sql',
    ).readAsStringSync();
    feedSql = File(
      'supabase/migrations/20261003221000_project14_feed_notifications.sql',
    ).readAsStringSync();
    aiSql = File(
      'supabase/migrations/20261003213000_project11_ai_orchestration.sql',
    ).readAsStringSync();
  });

  group('Knowledge / research review gates', () {
    test('knowledge_items review_status includes draft through archived', () {
      expect(knowledgeSql, contains("'draft'"));
      expect(knowledgeSql, contains("'review'"));
      expect(knowledgeSql, contains("'approved'"));
      expect(knowledgeSql, contains("'rejected'"));
      expect(knowledgeSql, contains("'archived'"));
    });

    test('public knowledge read requires approved status', () {
      expect(knowledgeSql, contains("review_status = 'approved'"));
      expect(knowledgeSql, contains('approved knowledge public read'));
    });

    test('research findings default to review not published', () {
      expect(knowledgeSql, contains("default 'review'"));
      expect(knowledgeSql, contains("'review','approved','rejected'"));
    });

    test('content_drafts include published only as explicit status', () {
      expect(
        knowledgeSql,
        contains("'draft','review','approved','rejected','published'"),
      );
    });

    test('source authority distinguishes rad_official from government', () {
      expect(knowledgeSql, contains("'rad_official'"));
      expect(knowledgeSql, contains("'government'"));
      expect(knowledgeSql, contains("'embassy'"));
      expect(knowledgeSql, isNot(contains("'rad_official'='government'")));
    });

    test('knowledge conflicts retain dual statements', () {
      expect(knowledgeSql, contains('statement_a'));
      expect(knowledgeSql, contains('statement_b'));
      expect(knowledgeSql, contains('proposed_interpretation'));
      expect(
        knowledgeSql,
        contains("'open','reviewing','resolved','dismissed'"),
      );
    });

    test('research jobs bound retries with max_attempts', () {
      expect(knowledgeSql, contains('max_attempts'));
      expect(knowledgeSql, contains('between 1 and 5'));
    });
  });

  group('Feed publish visibility', () {
    test('feed public read requires published status', () {
      expect(feedSql, contains("status='published'"));
      expect(feedSql, contains('published_at<=now()'));
      expect(feedSql, contains('published feed public read'));
    });

    test('feed status machine includes draft through archived', () {
      expect(feedSql, contains("'draft','review','published','archived'"));
    });

    test('saved feed and reads are owner-scoped', () {
      expect(feedSql, contains('users manage saved feed'));
      expect(feedSql, contains('user_id=(select auth.uid())'));
    });

    test('notifications are owner-scoped', () {
      expect(feedSql, contains('users read own notifications'));
      expect(feedSql, contains('users mark own notifications'));
    });

    test('feed localizations support fa and en', () {
      expect(feedSql, contains("'fa','en'"));
      expect(feedSql, contains('feed_item_localizations'));
    });
  });

  group('AI provider secret isolation', () {
    test('API keys use vault secret_id not plaintext column', () {
      expect(aiSql, contains('secret_id'));
      expect(aiSql, contains('vault.create_secret'));
      expect(aiSql, contains('vault.update_secret'));
      expect(
        aiSql.contains('api_key text'),
        isFalse,
        reason: 'plaintext api_key column must not exist on providers',
      );
    });

    test('configure_ai_provider requires super_admin', () {
      expect(aiSql, contains("private.has_role(array['super_admin'])"));
      expect(aiSql, contains('configure_ai_provider'));
    });

    test('runtime chain is service_role only', () {
      expect(aiSql, contains('get_ai_runtime_chain'));
      expect(aiSql, contains("auth.jwt()->>'role'"));
      expect(aiSql, contains("<> 'service_role'"));
      expect(
        aiSql,
        contains('grant execute on function public.get_ai_runtime_chain'),
      );
    });

    test('enabled providers and models gate metadata reads', () {
      expect(aiSql, contains('enabled provider metadata read'));
      expect(aiSql, contains('enabled model metadata read'));
    });

    test('request attempt_count is bounded', () {
      expect(aiSql, contains('attempt_count between 0 and 5'));
    });
  });
}
