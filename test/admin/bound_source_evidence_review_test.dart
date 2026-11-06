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
  final List<String> modes = [];
  String? savedNote;
  bool malformedSave = false;
  @override
  Future<Map<String, dynamic>> save({
    required Map<String, dynamic> context,
    required String mode,
    required Map<String, String> decisions,
    required Map<String, String> edits,
    required String note,
  }) async {
    modes.add(mode);
    savedNote = note;
    if (malformedSave) return {'published': true};
    value['review_revision'] = (value['review_revision'] as int) + 1;
    value['note'] = note;
    return {
      'published': false,
      'draft_revision': null,
      'review_revision': value['review_revision'],
    };
  }

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
    'bound_source_change': <String, dynamic>{
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

Future<FixtureReviewRepository> mountReview(
  WidgetTester tester, {
  required bool withEvidence,
  required Locale locale,
  required double width,
  bool corruptEvidence = false,
  bool withReviewMetadata = false,
  bool corruptReviewMetadata = false,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final context = reviewContext(withEvidence: withEvidence);
  if (withReviewMetadata) {
    (context['bound_source_change'] as Map)['review_metadata'] = {
      'publisher_name': 'Synthetic government publisher',
      'jurisdiction': 'CA',
      'authority_state': 'verified',
      'context_scope': corruptReviewMetadata
          ? 'verified_capture'
          : 'current_registry_context_not_capture_verification',
      'old_fetched_at': '2026-10-29T00:00:00Z',
      'new_fetched_at': '2026-10-30T00:00:00Z',
      'source_published_at': null,
      'effective_date': null,
      'uncertainty_code': 'human_legal_review_required',
      'change_classification': 'bound_source_text_change',
    };
  }
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
  return repository;
}

void main() {
  testWidgets(
    'review metadata separates current registry and capture times from legal dates',
    (tester) async {
      await mountReview(
        tester,
        withEvidence: true,
        withReviewMetadata: true,
        locale: const Locale('en'),
        width: 1200,
      );
      expect(
        find.text(
          'Current registry context — not verification of this capture',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Publisher: Synthetic government publisher'),
        findsOneWidget,
      );
      expect(find.text('Jurisdiction: CA'), findsOneWidget);
      expect(
        find.text('Effective date: Not established by this evidence'),
        findsOneWidget,
      );
      expect(
        find.text('Source publication date: Not established by this evidence'),
        findsOneWidget,
      );
      expect(
        find.text('Source text changed; legal meaning requires human review.'),
        findsOneWidget,
      );
      expect(find.textContaining('2026-10-29T00:00:00Z'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('metadata cannot relabel current registry as verified capture', (
    tester,
  ) async {
    await mountReview(
      tester,
      withEvidence: true,
      withReviewMetadata: true,
      corruptReviewMetadata: true,
      locale: const Locale('en'),
      width: 1200,
    );
    expect(
      find.text('پاسخ سرویس معتبر نیست؛ عملیات تأیید نشد.'),
      findsOneWidget,
    );
    expect(find.text('Complete page comparison — unpublished'), findsNothing);
    expect(tester.takeException(), isNull);
  });
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
        expect(
          source.textSpan,
          isNotNull,
          reason: 'Source replacements need selectable highlighted text, not two plain quotations.',
        );
        expect(
          source.textSpan!.toPlainText(includeSemanticsLabels: false),
          'Old English excerpt <b>verbatim</b>.',
        );
        final spans = (source.textSpan as TextSpan).children!
            .whereType<TextSpan>();
        expect(
          spans.any((s) => s.style?.decoration == TextDecoration.lineThrough),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'invalid defer receipt never claims success or clears reviewer notes',
    (tester) async {
      final repository = await mountReview(
        tester,
        withEvidence: true,
        locale: const Locale('en'),
        width: 1200,
      );
      repository.malformedSave = true;
      await tester.enterText(
        find.byType(TextField),
        'Keep this unsaved evidence question.',
      );
      await tester.ensureVisible(find.text('Defer decision'));
      await tester.tap(find.text('Defer decision'));
      await tester.pumpAndSettle();
      expect(repository.modes, ['save_review']);
      expect(
        find.text('Review saved for later. The proposal remains pending.'),
        findsNothing,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep this unsaved evidence question.',
      );
      expect(
        find.text('Review was not saved. Refresh if the version changed.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'deferring persists reviewer notes without acceptance or draft creation',
    (tester) async {
      final repository = await mountReview(
        tester,
        withEvidence: true,
        locale: const Locale('en'),
        width: 1200,
      );
      await tester.enterText(
        find.byType(TextField),
        'Verify effective date before deciding.',
      );
      await tester.ensureVisible(find.text('Defer decision'));
      await tester.tap(find.text('Defer decision'));
      await tester.pumpAndSettle();
      expect(repository.modes, ['save_review']);
      expect(repository.savedNote, 'Verify effective date before deciding.');
      expect(
        find.text('Review saved for later. The proposal remains pending.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
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
