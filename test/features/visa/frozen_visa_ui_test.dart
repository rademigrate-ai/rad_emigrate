import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/data/frozen_visa_content.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/editorial_article_page.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/country_visa_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> country;
  late Map<String, dynamic> article;
  late String articleId;
  late String articleLocale;

  // Flutter test's fake-async widget zone does not permit awaiting a platform
  // asset load before the first pump. Do source I/O in real async setup.
  setUpAll(() async {
    final snapshot = FrozenVisaContent();
    country = await snapshot.country('AE', 'fa');
    final index = jsonDecode(
      await rootBundle.loadString('assets/visa_frozen_content/index.json'),
    ) as Map<String, dynamic>;
    final rows = (index['articles'] as List).cast<Map>();
    rows.sort(
      (a, b) => (a['block_count'] as int).compareTo(b['block_count'] as int),
    );
    articleId = rows.first['id'] as String;
    articleLocale = rows.first['locale'] as String;
    article = await snapshot.article(articleId, articleLocale);
  });

  testWidgets('actual sourced AE article is visible in Visa country view', (
    tester,
  ) async {
    final allCards = [
      ...country['categories'] as List,
      ...country['other_titles'] as List,
    ];
    expect(allCards, isNotEmpty);
    final card = allCards.first as Map;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countryVisaContentProvider((
            country: 'AE',
            locale: 'fa',
            preview: false,
          )).overrideWith((ref) async => country),
        ],
        child: const MaterialApp(
          locale: Locale('fa'),
          supportedLocales: [Locale('fa'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              child: CountryVisaContent(countryCode: 'AE'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(card['title'] as String), findsWidgets);
  });

  testWidgets('reader shows original content and source disclosure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editorialArticleProvider((
            id: articleId,
            locale: articleLocale,
            preview: false,
          )).overrideWith((ref) async => article),
        ],
        child: MaterialApp(
          locale: Locale(articleLocale),
          home: EditorialArticlePage(
            articleId: articleId,
            locale: articleLocale,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(article['title'] as String), findsWidgets);
    expect(
      find.textContaining(
        articleLocale == 'fa'
            ? 'نسخهٔ فقط‌خواندنی'
            : 'Read-only source snapshot',
      ),
      findsWidgets,
    );
    expect(article['rich_sections'], isNotEmpty);
  });
}
