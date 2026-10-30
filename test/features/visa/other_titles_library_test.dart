import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/other_titles_library_page.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/editorial_article_page.dart';
import 'package:rad_emigrate/features/visa/presentation/visa_routes.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'global Other Titles preserves general and multi-country identities across pages',
    (tester) async {
      const first = (locale: 'en', preview: false, cursor: null);
      const second = (locale: 'en', preview: false, cursor: 'signed-page-2');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            otherTitlesLibraryProvider(first).overrideWith(
              (ref) async => {
                'items': [
                  {
                    'id': 'global',
                    'title': 'General source article',
                    'country_codes': [],
                    'source_publishers': ['radmohajer.ir'],
                  },
                  {'id': 'global', 'title': 'Duplicate identity'},
                  {
                    'id': 'multi',
                    'title': 'Country comparison',
                    'country_codes': ['CA', 'DE'],
                    'source_publishers': ['digivisa.ir', 'radvisa.com'],
                  },
                ],
                'has_more': true,
                'next_cursor': 'signed-page-2',
              },
            ),
            otherTitlesLibraryProvider(second).overrideWith(
              (ref) async => {
                'items': [
                  {'id': 'next', 'title': 'Second page original'},
                ],
                'has_more': false,
                'next_cursor': null,
              },
            ),
          ],
          child: const MaterialApp(home: OtherTitlesLibraryPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('General source article'), findsOneWidget);
      expect(find.text('Duplicate identity'), findsNothing);
      expect(find.textContaining('radmohajer.ir'), findsOneWidget);
      expect(find.textContaining('Canada · Germany'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Second page original'), findsOneWidget);
      expect(find.text('General source article'), findsNothing);
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('General source article'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('global preview deep link keeps preview on article reader', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/visa/other-titles?preview=true',
      routes: [visaRoute()],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          otherTitlesLibraryProvider((
            locale: 'en',
            preview: true,
            cursor: null,
          )).overrideWith(
            (ref) async => {
              'items': [
                {
                  'id': 'draft-id',
                  'title': 'Unpublished general original',
                  'country_codes': [],
                },
              ],
              'has_more': false,
              'next_cursor': null,
            },
          ),
          editorialArticleProvider((
            id: 'draft-id',
            locale: 'en',
            preview: true,
          )).overrideWith(
            (ref) async => {
              'title': 'Complete original draft',
              'rich_sections': [],
              'sources': [],
            },
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpublished general original'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditorialArticlePage>(find.byType(EditorialArticlePage))
          .preview,
      isTrue,
    );
    expect(
      router.routeInformationProvider.value.uri.queryParameters['preview'],
      'true',
    );
    expect(find.text('Complete original draft'), findsOneWidget);
  });

  testWidgets('denied preview is an explicit retry with no draft fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          otherTitlesLibraryProvider((
            locale: 'en',
            preview: true,
            cursor: null,
          )).overrideWith((ref) async => throw StateError('forbidden')),
          otherTitlesLibraryProvider((
            locale: 'en',
            preview: false,
            cursor: null,
          )).overrideWith(
            (ref) async => {
              'items': [
                {'id': 'unexpected', 'title': 'Wrong fallback'},
              ],
              'has_more': false,
            },
          ),
        ],
        child: const MaterialApp(home: OtherTitlesLibraryPage(preview: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Articles unavailable; retry'), findsOneWidget);
    expect(find.text('Wrong fallback'), findsNothing);
    expect(find.text('No published articles on this page.'), findsNothing);
  });
}
