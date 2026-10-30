import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/editorial_article_page.dart';

const sourceId = 'a1000000-0000-4000-8000-000000000001';
const targetId = 'a1000000-0000-4000-8000-000000000002';
const originalUrl = 'https://radvisa.com/article/source#costs';

void main() {
  testWidgets(
    'preview opens the full mapped source destination and retains the exact original URL',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/visa/content/$sourceId?locale=en&preview=true',
        routes: [
          GoRoute(
            path: '/visa/content/:id',
            builder: (_, state) => EditorialArticlePage(
              articleId: state.pathParameters['id']!,
              locale: state.uri.queryParameters['locale']!,
              preview: state.uri.queryParameters['preview'] == 'true',
              initialSectionAnchor: state.uri.fragment,
              requestedLocale: state.uri.queryParameters['requested_locale'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editorialArticleProvider((
              id: sourceId,
              locale: 'en',
              preview: true,
            )).overrideWith(
              (ref) async => {
                'title': 'Source reader',
                'rich_sections': [],
                'source_links': [
                  {
                    'url': 'https://radvisa.com/article/source',
                    'original_url': originalUrl,
                    'label': 'Known source',
                    'app_article_id': targetId,
                    'app_locale': 'fa',
                    'app_fragment': 'retained-block',
                  },
                ],
              },
            ),
            editorialArticleProvider((
              id: targetId,
              locale: 'fa',
              preview: true,
            )).overrideWith(
              (ref) async => {
                'title': 'متن کامل منبع',
                'rich_sections': [
                  {
                    'heading': 'Costs',
                    'blocks': [
                      {
                        'id': 'retained-block',
                        'type': 'paragraph',
                        'text': 'All retained content',
                      },
                    ],
                  },
                ],
              },
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Original source — $originalUrl'), findsOneWidget);
      await tester.tap(find.text('Known source — Read in RAD'));
      await tester.pumpAndSettle();
      // Imperative GoRouter.push retains the base route-information URI.
      // Assert the actual pushed page and its complete navigation contract.
      final targetPage = tester.widget<EditorialArticlePage>(
        find.byType(EditorialArticlePage).last,
      );
      expect(targetPage.articleId, targetId);
      expect(targetPage.preview, isTrue);
      expect(targetPage.locale, 'fa');
      expect(targetPage.requestedLocale, 'en');
      expect(targetPage.initialSectionAnchor, 'retained-block');
      expect(find.text('All retained content'), findsOneWidget);
    },
  );

  testWidgets(
    'raw mapping metadata never creates public links to imported drafts',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editorialArticleProvider((
              id: sourceId,
              locale: 'en',
              preview: false,
            )).overrideWith(
              (ref) async => {
                'title': 'Public reader',
                'rich_sections': [],
                'source_links': [
                  {
                    'url': originalUrl,
                    'label': 'Known source',
                    'app_article_id': targetId,
                    'app_locale': 'fa',
                    'app_public_available': true,
                  },
                ],
              },
            ),
          ],
          child: const MaterialApp(
            home: EditorialArticlePage(articleId: sourceId, locale: 'en'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Known source — $originalUrl'), findsOneWidget);
      expect(find.textContaining('Read in RAD'), findsNothing);
      expect(find.text('Original source — $originalUrl'), findsNothing);
    },
  );
}
