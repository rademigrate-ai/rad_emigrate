import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Stage 2 acceptance: review → explicit publish, no auto-publish.
void main() {
  final root = Directory.current.path;
  String read(String relative) =>
      File('$root/$relative').readAsStringSync();

  test('publish_content_draft RPC exists and is admin-gated', () {
    final sql = read(
      'supabase/migrations/20261005120000_stage2_review_feed_publish.sql',
    );
    expect(sql.contains('create or replace function public.publish_content_draft'), isTrue);
    expect(sql.contains("private.has_role(array['admin','super_admin'])"), isTrue);
    expect(sql.contains("raise exception 'forbidden'"), isTrue);
    expect(sql.contains("raise exception 'rejected draft cannot be published'"), isTrue);
    expect(sql.contains('Idempotent'), isTrue);
    expect(sql.contains("status = 'published'"), isTrue);
    expect(sql.contains('feed_item_localizations'), isTrue);
  });

  test('research candidate creation never writes feed_items', () {
    final stage1 = read(
      'supabase/migrations/20261005102000_stage1_ai_research_completion.sql',
    );
    expect(stage1.contains('create_research_review_candidate'), isTrue);
    expect(stage1.contains('content_drafts'), isTrue);
    expect(stage1.contains("status,'review'"), isTrue);
    // No feed write in Stage 1 candidate path.
    final fnStart = stage1.indexOf('create_research_review_candidate');
    final fnBody = stage1.substring(fnStart, fnStart + 800);
    expect(fnBody.contains('feed_items'), isFalse);
    expect(fnBody.contains('publish'), isFalse);
  });

  test('research-sync worker does not publish feed', () {
    final worker = read('supabase/functions/research-sync/index.ts');
    expect(worker.toLowerCase().contains('feed_items'), isFalse);
    expect(worker.contains('publish_content_draft'), isFalse);
    expect(worker.contains("status: 'published'"), isFalse);
  });

  test('set_content_draft_status supports reject/keep/approve without publish', () {
    final sql = read(
      'supabase/migrations/20261005120000_stage2_review_feed_publish.sql',
    );
    expect(sql.contains('set_content_draft_status'), isTrue);
    expect(sql.contains("'draft','review','approved','rejected'"), isTrue);
    expect(sql.contains("status is distinct from 'published'"), isTrue);
  });

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
