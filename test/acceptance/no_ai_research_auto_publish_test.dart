import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// RESEARCH OR AI MUST NEVER AUTO-PUBLISH TO FEED.
void main() {
  final root = Directory.current.path;
  String read(String relative) => File('$root/$relative').readAsStringSync();

  test('ai-orchestrator never writes feed_items or publish_content_draft', () {
    final fn = read('supabase/functions/ai-orchestrator/index.ts');
    expect(fn.toLowerCase().contains('feed_items'), isFalse);
    expect(fn.contains('publish_content_draft'), isFalse);
  });

  test('research-sync never publishes feed', () {
    final worker = read('supabase/functions/research-sync/index.ts');
    expect(worker.toLowerCase().contains('feed_items'), isFalse);
    expect(worker.contains('publish_content_draft'), isFalse);
  });

  test('create_research_review_candidate creates drafts not feed', () {
    final stage1 = read(
      'supabase/migrations/20261005102000_stage1_ai_research_completion.sql',
    );
    const start =
        'create or replace function public.create_research_review_candidate';
    final i = stage1.indexOf(start);
    expect(i, greaterThanOrEqualTo(0));
    final body = stage1.substring(i, (i + 3500).clamp(0, stage1.length));
    expect(body.contains('content_drafts'), isTrue);
    expect(body.contains('feed_items'), isFalse);
  });

  test('Feed repository only loads published items', () {
    final repo = read('lib/features/feed/data/feed_repository.dart');
    expect(repo.contains(".eq('status', 'published')"), isTrue);
  });
}
