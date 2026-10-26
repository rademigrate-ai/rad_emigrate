import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/editorial_source_review.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/editorial_scroll_body.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/editorial_article_page.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/editorial_rich_block.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/other_titles.dart';

void main() {
  testWidgets('Other Titles has one exact label and unique identity links', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OtherTitles(
            locale: 'fa',
            items: [
              {'id': 'a', 'title': 'Independent title'},
              {'id': 'a', 'title': 'Duplicate same identity'},
            ],
          ),
        ),
      ),
    );
    expect(find.text('دیگر عناوین'), findsOneWidget);
    expect(find.text('Independent title'), findsOneWidget);
    expect(find.text('Duplicate same identity'), findsNothing);
  });

  testWidgets(
    'rich tables preserve cells, captions and spans at mobile width',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: EditorialRichBlock(
                block: {
                  'type': 'table',
                  'text': 'Heading A B C',
                  'rows': [
                    [
                      {
                        'text': 'Heading',
                        'header': true,
                        'colspan': '2',
                        'rowspan': '1',
                      },
                    ],
                    [
                      {
                        'text': 'A',
                        'header': false,
                        'colspan': '1',
                        'rowspan': '2',
                      },
                      {
                        'text': 'B',
                        'header': false,
                        'colspan': '1',
                        'rowspan': '1',
                      },
                    ],
                    [
                      {
                        'text': 'C',
                        'header': false,
                        'colspan': '1',
                        'rowspan': '1',
                      },
                    ],
                  ],
                  'caption': 'Synthetic caption',
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('Synthetic caption'), findsOneWidget);
      for (final value in ['Heading', 'A', 'B', 'C']) {
        expect(find.text(value), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'continuous reader preserves body and explicit RTL without source cards',
    (tester) async {
      const key = (id: 'synthetic', locale: 'fa', preview: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editorialArticleProvider(key).overrideWith(
              (ref) async => {
                'title': 'Synthetic category',
                'rich_sections': [
                  {
                    'heading': 'Requirements',
                    'blocks': [
                      {
                        'type': 'heading',
                        'text': 'Requirements',
                        'original_structure': {
                          'type': 'heading',
                          'text': 'Requirements',
                          'level': 2,
                        },
                      },
                      {
                        'type': 'paragraph',
                        'text': 'First complete explanation.',
                      },
                      {'type': 'paragraph', 'text': 'Second unique condition.'},
                    ],
                  },
                ],
                'sources': [],
                'other_titles': [],
              },
            ),
          ],
          child: const MaterialApp(
            home: EditorialArticlePage(
              articleId: 'synthetic',
              locale: 'fa',
              preview: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Requirements'), findsOneWidget);
      expect(find.text('First complete explanation.'), findsOneWidget);
      expect(find.text('Second unique condition.'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.text('First complete explanation.')),
        ),
        TextDirection.rtl,
      );
      expect(find.textContaining('پیش‌نویس تأییدنشده'), findsOneWidget);
    },
  );

  testWidgets(
    'missing English stays unavailable and retry makes a new request',
    (tester) async {
      var calls = 0;
      const key = (id: 'synthetic', locale: 'en', preview: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editorialArticleProvider(key).overrideWith((ref) async {
              calls++;
              throw StateError('article_or_translation_not_found');
            }),
          ],
          child: const MaterialApp(
            home: EditorialArticlePage(articleId: 'synthetic', locale: 'en'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Content or translation is unavailable.'),
        findsOneWidget,
      );
      expect(
        Directionality.of(tester.element(find.text('Retry'))),
        TextDirection.ltr,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Synthetic category'), findsNothing);
    },
  );
  testWidgets('a private original-source dialog clears on account change', (
    tester,
  ) async {
    final identity = StreamController<String?>();
    addTearDown(identity.close);
    const key = (
      articleId: 'article',
      revisionId: 'revision',
      snapshotId: 'snapshot',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAuthUserIdProvider.overrideWith((ref) => identity.stream),
          editorialSourceSnapshotProvider(key).overrideWith(
            (ref) async => {
              'title': 'Synthetic source',
              'locale': 'en',
              'body_text': 'PRIVATE REVIEW BODY',
              'url': 'https://example.invalid/source',
            },
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SourceReviewButton(
              article: {
                'id': 'article',
                'revision_id': 'revision',
                'composition': {
                  'sections': [
                    {
                      'blocks': [
                        {
                          'provenance': [
                            {
                              'snapshot_id': 'snapshot',
                              'url': 'https://example.invalid/source',
                            },
                          ],
                        },
                      ],
                    },
                  ],
                },
              },
            ),
          ),
        ),
      ),
    );
    identity.add('admin-one');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Original sources (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('https://example.invalid/source'));
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE REVIEW BODY'), findsOneWidget);
    identity.add('different-account');
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE REVIEW BODY'), findsNothing);
    expect(find.textContaining('Session changed.'), findsOneWidget);
  });

  testWidgets('lazy long-form reader seeks the exact target block', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorialScrollBody(
            targetIndex: 150,
            children: List.generate(
              180,
              (i) => SizedBox(
                height: 40 + (i % 7) * 7,
                child: Text('Unique block $i'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unique block 150'), findsOneWidget);
    final rect = tester.getRect(find.text('Unique block 150'));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.top, lessThan(500));
  });

  testWidgets('legacy flat lists retain every item in the additive reader', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorialRichBlock(
            block: {
              'type': 'numbered_list',
              'text': '',
              'items': ['First unique item', 'Second unique item'],
            },
          ),
        ),
      ),
    );
    expect(find.text('1. First unique item'), findsOneWidget);
    expect(find.text('2. Second unique item'), findsOneWidget);
  });
}
