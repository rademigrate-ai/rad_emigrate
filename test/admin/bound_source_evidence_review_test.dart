import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/features/admin/data/research_review_repository.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_full_page_diff_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

const testOwner = 'a1111111-1111-4111-8111-111111111111';

class FixtureReviewRepository implements ResearchReviewRepository {
  FixtureReviewRepository(this.value);
  final Map<String, dynamic> value;
  @override
  Future<Map<String, dynamic>> context(String proposalId) async => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> reviewContext({required bool withEvidence}) => {
  'proposal': {
    'id': 'proposal',
    'revision': 1,
    'target_article_id': 'article',
    'base_revision': 1,
    'created_at': '2026-10-30T00:00:00Z',
    'verification_state': 'unverified',
    'editorial_state': 'review',
    'changes': [],
    'evidence': [],
  },
  'base': {
    'revision_id': 'base',
    'content_hash': 'base-hash',
    'title': 'Synthetic review',
    'body': {'sections': []},
    'rich_sections': [],
  },
  'structured_patches': [],
  'base_rich_hash': 'rich-hash',
  'review_revision': 0,
  'stale': false,
  'decisions': [],
  if (withEvidence)
    'bound_source_change': {
      'source_url': 'https://official.example.org/source',
      'source_language': 'en',
      'article_locale': 'fa',
      'old_snapshot_id': '81000000-0000-4000-8000-000000000041',
      'new_snapshot_id': '81000000-0000-4000-8000-000000000042',
      'old_content_hash': 'a' * 64,
      'new_content_hash': 'b' * 64,
      'old_fragment': 'Old English excerpt <b>verbatim</b>.',
      'new_fragment': 'New English excerpt preserved verbatim.',
      'interpretation': 'verbatim source evidence only; no translation or legal interpretation',
    },
};

Future<void> mountReview(
  WidgetTester tester, {
  required bool withEvidence,
  required Locale locale,
  required double width,
  bool corruptEvidence = false,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final context = reviewContext(withEvidence: withEvidence);
  if (corruptEvidence) {
    (context['bound_source_change'] as Map).remove('old_content_hash');
  }
  final repository = FixtureReviewRepository(context);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        researchReviewRepositoryProvider.overrideWithValue(repository),
        adminResearchActorReaderProvider.overrideWithValue(() => testOwner),
        supabaseAuthUserIdProvider.overrideWith(
          (ref) => Stream.value(testOwner),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminFullPageDiffPage(sourceId: 'proposal'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (width, locale) in [
    (390.0, const Locale('fa')),
    (1200.0, const Locale('en')),
  ]) {
    testWidgets(
      'bound evidence keeps original source language, fragments and full identity at $width',
      (tester) async {
        await mountReview(
          tester,
          withEvidence: true,
          locale: locale,
          width: width,
        );
        expect(
          find.text('Old English excerpt <b>verbatim</b>.'),
          findsOneWidget,
        );
        expect(
          find.text('New English excerpt preserved verbatim.'),
          findsOneWidget,
        );
        expect(
          find.text('https://official.example.org/source'),
          findsOneWidget,
        );
        expect(
          find.text('81000000-0000-4000-8000-000000000041'),
          findsOneWidget,
        );
        expect(
          find.text('81000000-0000-4000-8000-000000000042'),
          findsOneWidget,
        );
        expect(find.text('a' * 64), findsOneWidget);
        expect(find.text('b' * 64), findsOneWidget);
        expect(find.textContaining('English (en)'), findsOneWidget);
        expect(find.textContaining('فارسی (fa)'), findsOneWidget);
        expect(
          find.text(
            locale.languageCode == 'fa'
                ? 'متن اصلی منبع — ترجمه نشده'
                : 'Original source text — not translated',
          ),
          findsOneWidget,
        );
        final source = tester.widget<SelectableText>(
          find.ancestor(
            of: find.text('Old English excerpt <b>verbatim</b>.'),
            matching: find.byType(SelectableText),
          ),
        );
        expect(source.textDirection, TextDirection.ltr);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'prior Stage7 context without bound metadata remains reviewable',
    (tester) async {
      await mountReview(
        tester,
        withEvidence: false,
        locale: const Locale('en'),
        width: 1200,
      );
      expect(
        find.text('Complete page comparison — unpublished'),
        findsOneWidget,
      );
      expect(find.text('Original source text — not translated'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'incomplete bound evidence blocks review rather than hiding missing provenance',
    (tester) async {
      await mountReview(
        tester,
        withEvidence: true,
        locale: const Locale('en'),
        width: 1200,
        corruptEvidence: true,
      );
      expect(
        find.text('پاسخ سرویس معتبر نیست؛ عملیات تأیید نشد.'),
        findsOneWidget,
      );
      expect(find.text('Complete page comparison — unpublished'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
