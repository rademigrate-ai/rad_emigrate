import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Stage 2 acceptance: review → explicit publish, no auto-publish.
void main() {
  final root = Directory.current.path;
  String read(String relative) => File('$root/$relative').readAsStringSync();

  test('publish_content_draft RPC exists and is admin-gated', () {
    final sql = read(
      'supabase/migrations/20261010010000_stage1_p0_security_completion.sql',
    );
    expect(
      sql.contains('create or replace function public.publish_content_draft'),
      isTrue,
    );
    expect(
      sql.contains("private.has_role(array['admin','super_admin'])"),
      isTrue,
    );
    expect(sql.contains("raise exception 'forbidden'"), isTrue);
    expect(sql.contains('draft requires explicit approval'), isTrue);
    expect(sql.contains('rad.human_publish_actor'), isTrue);
    expect(sql.contains('trg_guard_human_feed_item_mutation'), isTrue);
    expect(sql.contains('revoke insert, update, delete'), isTrue);
    expect(sql.contains("status = 'published'"), isTrue);
    expect(sql.contains('feed_item_localizations'), isTrue);
  });

  test('research candidate creation never writes feed_items', () {
    final stage1 = read(
      'supabase/migrations/20261005102000_stage1_ai_research_completion.sql',
    );
    expect(stage1.contains('create_research_review_candidate'), isTrue);
    expect(stage1.contains('content_drafts'), isTrue);
    expect(stage1.contains("'review'"), isTrue);

    // Inspect the complete candidate function rather than a fixed-size source
    // window. Formatting and finding-linkage changes must not make this safety
    // assertion brittle.
    const functionStart =
        'create or replace function public.create_research_review_candidate';
    const functionEnd =
        'alter function public.create_research_review_candidate';
    final start = stage1.indexOf(functionStart);
    final end = stage1.indexOf(functionEnd, start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final fnBody = stage1.substring(start, end);
    expect(fnBody.contains('feed_items'), isFalse);
    expect(fnBody.contains('publish_content_draft'), isFalse);
  });

  test('research-sync worker does not publish feed', () {
    final worker = read('supabase/functions/research-sync/handler.ts');
    expect(worker.toLowerCase().contains('feed_items'), isFalse);
    expect(worker.contains('publish_content_draft'), isFalse);
    expect(worker.contains("status: 'published'"), isFalse);
  });

  test(
    'set_content_draft_status supports reject/keep/approve without publish',
    () {
      final sql = read(
        'supabase/migrations/20261005120000_stage2_review_feed_publish.sql',
      );
      expect(sql.contains('set_content_draft_status'), isTrue);
      expect(sql.contains("'draft','review','approved','rejected'"), isTrue);
      expect(sql.contains("status is distinct from 'published'"), isTrue);
    },
  );

  test('update_content_draft preserves separate provenance path', () {
    final sql = read(
      'supabase/migrations/20261005120000_stage2_review_feed_publish.sql',
    );
    expect(sql.contains('update_content_draft'), isTrue);
    // Editing title/body only; no delete of research_job_id / primary_source_id.
    expect(sql.contains('research_job_id'), isFalse); // not wiped in update fn
    expect(sql.contains('p_title'), isTrue);
    expect(sql.contains('p_body'), isTrue);
  });

  test('feed public read remains published-only via RLS policy source', () {
    final feed = read(
      'supabase/migrations/20261003222909_project14_feed_notifications.sql',
    );
    expect(feed.contains("status='published'"), isTrue);
    expect(feed.contains('published feed public read'), isTrue);
  });
}
