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
  late String ssrfSql;

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
    ssrfSql = File(
      'supabase/migrations/20261003235000_ai_base_url_ssrf_hardening.sql',
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
      expect(knowledgeSql, contains("'embassy'"));
      expect(knowledgeSql, contains("'government'"));
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
    test('API keys use vault secret_id not table column', () {
      expect(aiSql, contains('secret_id'));
      expect(aiSql, contains('vault.create_secret'));
      expect(aiSql, contains('vault.update_secret'));
      expect(aiSql, contains('vault.decrypted_secrets'));

      // Slice from ai_providers CREATE through next CREATE TABLE (models).
      final start = aiSql.indexOf('create table public.ai_providers');
      final end = aiSql.indexOf('create table public.ai_models');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final providersDdl = aiSql.substring(start, end);
      expect(
        providersDdl.contains(RegExp(r'\bapi_key\b')),
        isFalse,
        reason: 'plaintext api_key column must not exist on providers',
      );
      expect(providersDdl, contains('secret_id'));
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

  group('AI base_url SSRF hardening', () {
    test('is_safe_public_https_url helper exists', () {
      expect(ssrfSql, contains('private.is_safe_public_https_url'));
      expect(ssrfSql, contains('169.254.'));
      expect(ssrfSql, contains('localhost'));
      expect(ssrfSql, contains('metadata.google.internal'));
    });

    test('configure_ai_provider uses safe URL helper not only https prefix', () {
      expect(ssrfSql, contains('not private.is_safe_public_https_url(p_base_url)'));
      expect(ssrfSql, contains('configure_ai_provider'));
    });

    test('blocks private and loopback IPv4 ranges', () {
      expect(ssrfSql, contains("like '10.%'"));
      expect(ssrfSql, contains("like '192.168.%'"));
      expect(ssrfSql, contains("like '127.%'"));
      expect(ssrfSql, contains('172\\.(1[6-9]|2[0-9]|3[0-1])\\.'));
    });
  });
}
