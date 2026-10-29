import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/visa_content_countries_page.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/country_visa_content.dart';

void main() {
  testWidgets(
    'draft country list uses explicit preview and public stays separate',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visaContentCountriesProvider('en').overrideWith((ref) async => []),
            visaContentPreviewCountriesProvider('en').overrideWith(
              (ref) async => [
                {'country_code': 'CA', 'category_count': 1},
              ],
            ),
          ],
          child: const MaterialApp(
            home: VisaContentCountriesPage(preview: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Canada'), findsOneWidget);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visaContentCountriesProvider('en').overrideWith((ref) async => []),
            visaContentPreviewCountriesProvider('en')
                .overrideWith((ref) async => throw StateError('forbidden')),
          ],
          child: const MaterialApp(home: VisaContentCountriesPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Canada'), findsNothing);
      expect(find.textContaining('No approved published'), findsOneWidget);
    },
  );

  testWidgets(
    'country draft navigation passes preview to categories and Other Titles',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryVisaContentProvider((
              country: 'CA',
              locale: 'en',
              preview: true,
            )).overrideWith(
              (ref) async => {
                'categories': [
                  {'id': 'study', 'title': 'Draft study'},
                ],
                'other_titles': [
                  {'id': 'independent', 'title': 'Draft independent'},
                ],
              },
            ),
          ],
          child: const MaterialApp(
            home: VisaContentCountriesPage(countryCode: 'CA', preview: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CountryVisaContent>(find.byType(CountryVisaContent))
            .preview,
        isTrue,
      );
      expect(find.text('Draft study'), findsOneWidget);
      expect(find.text('Draft independent'), findsOneWidget);
      expect(find.text('Other Titles'), findsOneWidget);
    },
  );
}
