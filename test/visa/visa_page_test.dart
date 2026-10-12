import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/visa_page.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/visa_catalog_provider.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

const sourceUrl = 'https://authority.example/visa/program';

final catalog = VisaCatalog(
  countries: const [
    Country(
      id: 'country-1',
      name: 'Exampleland',
      code: 'EX',
      flagEmoji: '🏳️',
      slug: 'exampleland',
    ),
  ],
  categories: const [
    VisaCategory(
      id: 'category-1',
      name: 'Study',
      description: 'Study routes',
      slug: 'study',
    ),
  ],
  programs: [
    VisaProgram(
      id: 'program-1',
      slug: 'example-study',
      title: 'Example study visa',
      countryId: 'country-1',
      categoryId: 'category-1',
      summary: 'A reviewed programme summary.',
      source: VisaSource(
        title: 'Immigration authority',
        url: sourceUrl,
        publisher: 'Example Government',
        retrievedAt: DateTime.utc(2026, 10, 12),
      ),
    ),
  ],
);

void main() {
  testWidgets('Visa detail exposes its evidence URL as an accessible action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visaCatalogProvider('en').overrideWith((ref) async => catalog),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VisaPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Example study visa').first);
    await tester.pump();

    expect(find.widgetWithText(TextButton, sourceUrl), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
