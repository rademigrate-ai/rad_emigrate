import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/domain/entities/canonical_pathway_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/canonical_pathway_page.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/editorial_article_page.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/canonical_pathway_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'canonical source deep link uses the complete published rich reader',
    (tester) async {
      const key = (countryCode: 'DE', locale: 'en', pathwaySlug: 'study');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canonicalPathwayProvider(key).overrideWith(
              (ref) async => CanonicalPathwayArticle.fromJson({
                'id': 'source-fixture',
                'title': 'Source canonical article',
                'publication_basis': 'source_faithful',
                'verification_state': 'unverified',
                'editorial_state': 'published',
              }),
            ),
            editorialArticleProvider((
              id: 'source-fixture',
              locale: 'en',
              preview: false,
            )).overrideWith(
              (ref) async => {
                'title': 'Source canonical article',
                'publication_basis': 'source_faithful',
                'verification_state': 'unverified',
                'rich_sections': [
                  {
                    'heading': 'Full source section',
                    'blocks': [
                      {
                        'type': 'paragraph',
                        'text': 'Complete original source body.',
                      },
                    ],
                  },
                ],
                'other_titles': [],
              },
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CanonicalPathwayPage(countrySlug: 'DE', pathwaySlug: 'study'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Complete original source body.'), findsOneWidget);
      expect(
        find.textContaining('not been independently verified'),
        findsOneWidget,
      );
      expect(find.byType(EditorialArticlePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['en', 'fa']) {
    testWidgets('source publication keeps factual status explicit in $locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editorialArticleProvider((
              id: 'source-fixture',
              locale: locale,
              preview: false,
            )).overrideWith(
              (ref) async => {
                'title': 'Synthetic source article',
                'publication_basis': 'source_faithful',
                'verification_state': 'unverified',
                'sections': [],
                'other_titles': [],
                'source_links': [
                  {
                    'url': 'https://radvisa.com/evidence',
                    'label': 'Source link',
                    'href_evidence': {'confirmed': false},
                  },
                ],
              },
            ),
          ],
          child: MaterialApp(
            home: EditorialArticlePage(
              articleId: 'source-fixture',
              locale: locale,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          locale == 'fa'
              ? 'مستقلاً تأیید نشده‌اند'
              : 'not been independently verified',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          locale == 'fa'
              ? 'خراب بودن پیوند اثبات نشده'
              : 'link has not been shown to be broken',
        ),
        findsOneWidget,
      );
      final direction = tester.widget<Directionality>(
        find
            .descendant(
              of: find.byType(EditorialArticlePage),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(
        direction.textDirection,
        locale == 'fa' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
