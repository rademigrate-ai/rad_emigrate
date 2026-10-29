import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/editorial_article_page.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/editorial_rich_block.dart';

void main() {
  testWidgets(
    'reader exposes separately captured media and original links without invented body blocks',
    (tester) async {
      const key = (id: 'media-draft', locale: 'en', preview: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editorialArticleProvider(key).overrideWith(
              (ref) async => {
                'title': 'Original media article',
                'rich_sections': [],
                'source_assets': [
                  {
                    'kind': 'img',
                    'url': 'https://radvisa.com/original.jpg',
                    'alt': 'Captured alt text',
                    'public_render_allowed': false,
                  },
                ],
                'source_links': [
                  {
                    'url': 'https://radvisa.com/citation',
                    'label': 'Original reference',
                  },
                ],
              },
            ),
          ],
          child: const MaterialApp(
            home: EditorialArticlePage(
              articleId: 'media-draft',
              locale: 'en',
              preview: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Source media'), findsOneWidget);
      expect(find.text('Captured alt text'), findsOneWidget);
      expect(find.textContaining('Original reference'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );
  testWidgets(
    'unapproved media preserves caption and reference without inline reuse',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditorialRichBlock(
              block: {
                'type': 'image',
                'url': 'https://radvisa.com/original.jpg',
                'alt': 'Original illustration',
                'public_render_allowed': false,
              },
            ),
          ),
        ),
      );
      expect(find.text('Original illustration'), findsOneWidget);
      expect(find.text('https://radvisa.com/original.jpg'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets('unsafe media URL is never actionable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorialRichBlock(
            block: {
              'type': 'image',
              'url': 'javascript:alert(1)',
              'alt': 'Retained caption',
              'public_render_allowed': true,
            },
          ),
        ),
      ),
    );
    expect(find.text('Retained caption'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(Image), findsNothing);
  });
}
