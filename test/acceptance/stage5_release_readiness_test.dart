import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  final root = Directory.current.path;
  String read(String relative) => File('$root/$relative').readAsStringSync();

  group('research findings remain review-only', () {
    test('worker ingests evidence atomically into one review candidate', () {
      final worker = read('supabase/functions/research-sync/handler.ts');

      expect(worker, contains('rpc/ingest_research_snapshot'));
      final sql = read(
        'supabase/migrations/20261007080002_research_atomic_review_candidate.sql',
      );
      expect(sql, contains('after insert on public.research_findings'));
      expect(
        sql,
        contains(
          'public.create_research_review_candidate(new.research_job_id,new.id',
        ),
      );
      expect(sql, isNot(contains('insert into public.feed_items')));
      expect(worker, isNot(contains('publish_content_draft')));
      expect(worker.toLowerCase(), isNot(contains('feed_items')));
    });

    test('Stage 5 backfill is idempotent and never publishes', () {
      final migration = read(
        'supabase/migrations/'
        '20261006132931_stage5_research_review_candidate_backfill.sql',
      );

      expect(migration, contains('pg_advisory_xact_lock'));
      expect(migration, contains('where cd.research_finding_id = rf.id'));
      expect(migration, contains("'review'"));
      expect(migration, isNot(contains('publish_content_draft')));
      expect(migration, isNot(contains('insert into public.feed_items')));
    });
  });

  group('production initialization is evidence-conscious', () {
    test(
      'Visa seed is limited to programmes with specific source evidence',
      () {
        final migration = read(
          'supabase/migrations/20261005130000_stage2_visa_structured_steps.sql',
        );

        expect(migration, contains("p.slug = 'study-canada'"));
        expect(migration, contains("p.slug = 'work-germany'"));
        expect(migration, isNot(contains("p.slug in ('study-australia'")));
        expect(migration, isNot(contains("p.slug = 'medical-study-germany'")));
        expect(
          migration,
          isNot(contains('Valid identity documents and passport')),
        );
        expect(
          migration,
          isNot(contains('insert into public.visa_program_requirements')),
        );
      },
    );

    test('thin Visa content has bilingual, explicit review state', () {
      final page = read('lib/features/visa/presentation/pages/visa_page.dart');
      final en = lookupAppLocalizations(const Locale('en'));
      final fa = lookupAppLocalizations(const Locale('fa'));

      expect(page, contains('program.requirements.isEmpty'));
      expect(page, contains('program.steps.isEmpty'));
      expect(page, contains('structuredDetailsPendingBody'));
      expect(en.structuredDetailsPendingBody.trim(), isNotEmpty);
      expect(fa.structuredDetailsPendingBody.trim(), isNotEmpty);
      expect(
        en.structuredDetailsPendingBody,
        isNot(fa.structuredDetailsPendingBody),
      );
    });
  });

  group('release configuration and browser compatibility', () {
    test('Android release rejects the unapproved placeholder identity', () {
      final gradle = read('android/app/build.gradle.kts');

      expect(gradle, contains('RAD_ANDROID_APPLICATION_ID'));
      expect(gradle, contains('com.example.rad_emigrate'));
      expect(gradle, contains('placeholder package ID is not allowed'));
      expect(gradle, contains('dependsOn(verifyReleaseSigning)'));
    });

    test('Edge Functions share Supabase browser CORS headers', () {
      final cors = read('supabase/functions/_shared/cors.ts');
      expect(
        cors,
        contains('authorization, x-client-info, apikey, content-type'),
      );
      expect(cors, contains('x-rad-research-token'));
      for (final functionName in [
        'ai-orchestrator',
        'document-intelligence',
        'research-sync',
      ]) {
        final entrypoint = functionName == 'document-intelligence'
            ? 'index.ts'
            : 'handler.ts';
        final source = read('supabase/functions/$functionName/$entrypoint');
        final sharedSource = functionName == 'ai-orchestrator'
            ? read('supabase/functions/ai-orchestrator/handler_providers.ts')
            : source;
        expect(sharedSource, contains('../_shared/cors.ts'));
      }
    });

    test('Web and Render metadata are production-branded', () {
      final index = read('web/index.html');
      final manifest =
          jsonDecode(read('web/manifest.json')) as Map<String, dynamic>;
      final render = read('render.yaml');
      final build = read('scripts/build_web_render.sh');

      expect(index, contains('RAD International Institute'));
      expect(index, contains('dir="rtl"'));
      expect(manifest['name'], contains('RAD'));
      expect(manifest['short_name'], contains('RAD'));
      expect(render, contains('value: production'));
      expect(build, contains(r'APP_ENV:-production'));
    });
  });

  test('Admin overview queries are bounded and counted server-side', () {
    final repository = read(
      'lib/features/admin/data/admin_operations_repository.dart',
    );

    expect(repository, contains('.count()'));
    expect(repository, contains('.limit(200)'));
    expect(repository, isNot(contains('return rows.length')));
  });

  test('shared loading, empty, and error states expose semantics', () {
    final loading = read('lib/core/widgets/loading_state.dart');
    final empty = read('lib/core/widgets/empty_state.dart');
    final error = read('lib/core/widgets/error_state.dart');

    expect(loading, contains('liveRegion: true'));
    expect(empty, contains('explicitChildNodes: true'));
    expect(error, contains('liveRegion: true'));
    expect(error, contains('label: message'));
  });
}
