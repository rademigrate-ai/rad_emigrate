import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/editorial_article_page.dart';

void main() {
  testWidgets(
    'immutable passage fragment opens the exact late block of a long article',
    (tester) async {
      const key = (id: 'long-source', locale: 'en', preview: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editorialArticleProvider(key).overrideWith(
              (ref) async => {
                'title': 'Complete long article',
                'rich_sections': [
                  {
                    'id': 'section-one',
                    'heading': 'Original section',
                    'blocks': List.generate(
                      160,
                      (index) => {
                        'id': 'original-block-$index',
                        'type': 'paragraph',
                        'text':
                            'Original passage $index ${'full retained content ' * 12}',
                      },
                    ),
                  },
                ],
              },
            ),
          ],
          child: const MaterialApp(
            home: EditorialArticlePage(
              articleId: 'long-source',
              locale: 'en',
              preview: true,
              initialSectionAnchor: 'original-block-159',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Original passage 159 '), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
