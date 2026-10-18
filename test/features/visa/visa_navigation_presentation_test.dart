import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/directional_icons.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/visa_page.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/visa_catalog_provider.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Directional Icons RTL/LTR Flips', () {
    testWidgets(
      'directionalBack returns arrow_back in LTR and arrow_forward in RTL',
      (tester) async {
        late IconData ltrBack;
        late IconData rtlBack;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                ltrBack = directionalBack(context);
                return const SizedBox();
              },
            ),
          ),
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) {
                rtlBack = directionalBack(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(ltrBack, Icons.arrow_back);
        expect(rtlBack, Icons.arrow_forward);
      },
    );

    testWidgets(
      'directionalForward returns arrow_forward in LTR and arrow_back in RTL',
      (tester) async {
        late IconData ltrForward;
        late IconData rtlForward;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                ltrForward = directionalForward(context);
                return const SizedBox();
              },
            ),
          ),
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) {
                rtlForward = directionalForward(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(ltrForward, Icons.arrow_forward);
        expect(rtlForward, Icons.arrow_back);
      },
    );
  });

  group('Visa Navigation Presentation & Search Filter Empty State', () {
    final mockCatalog = VisaCatalog(
      countries: [
        const Country(
          id: 'ca',
          code: 'CA',
          flagEmoji: '🇨🇦',
          slug: 'canada',
          name: 'Canada',
          summary: 'Express Entry and PNP programs',
        ),
      ],
      categories: [
        const VisaCategory(
          id: 'work',
          slug: 'work',
          name: 'Work',
          description: 'Employment pathways',
        ),
      ],
      programs: [
        VisaProgram(
          id: 'express-entry',
          slug: 'express-entry',
          countryId: 'ca',
          categoryId: 'work',
          title: 'Express Entry',
          summary: 'Federal Skilled Worker',
          requirements: const [
            VisaRequirement(
              text: 'Language proficiency CLB 7+',
              displayOrder: 1,
              isMandatory: true,
            ),
          ],
          steps: const [
            VisaStep(
              title: 'Submit profile',
              description: 'Create express entry profile',
              displayOrder: 1,
            ),
          ],
          source: VisaSource(
            title: 'IRCC Portal',
            publisher: 'Government of Canada',
            url: 'https://canada.ca/express-entry',
            retrievedAt: DateTime(2026, 1, 1),
          ),
        ),
      ],
    );

    testWidgets(
      'empty search results show EmptyState with action to reset filters',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              visaCatalogProvider('en')
                  .overrideWith((ref) async => mockCatalog),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: VisaPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Canada'), findsOneWidget);

        // Search for nonexistent term
        final searchField = find.byType(TextFormField);
        await tester.enterText(searchField, 'nonexistent');
        await tester.pumpAndSettle();

        expect(find.text('Canada'), findsNothing);
        expect(find.byType(EmptyState), findsOneWidget);
        expect(
          find.text('Try changing the search or filters.'),
          findsOneWidget,
        );

        // Test clear button in search field
        final clearBtn = find.byIcon(Icons.clear);
        expect(clearBtn, findsOneWidget);
        await tester.tap(clearBtn);
        await tester.pumpAndSettle();

        expect(find.text('Canada'), findsOneWidget);
      },
    );
  });
}
