import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';
import 'package:rad_emigrate/core/widgets/inline_alert.dart';
import 'package:rad_emigrate/features/visa/domain/entities/university_scholarship.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/university_scholarship_page.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/university_scholarship_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final fixedClock = DateTime.utc(2026, 10, 18);

  final sampleFreshSource = CatalogSourceMeta(
    title: 'University of Toronto Official Registry',
    url: 'https://artsci.calendar.utoronto.ca/',
    publisher: 'University of Toronto Registrar',
    retrievedAt: fixedClock.subtract(const Duration(days: 15)),
  );

  final sampleTumSource = CatalogSourceMeta(
    title: 'TUM Degree Programs Overview',
    url: 'https://www.tum.de/en/studies/',
    publisher: 'Technical University of Munich Registrar',
    retrievedAt: fixedClock.subtract(const Duration(days: 10)),
  );

  final sampleDaadSource = CatalogSourceMeta(
    title: 'DAAD Scholarship Database',
    url: 'https://www.daad.de/scholarships/',
    publisher: 'German Academic Exchange Service',
    retrievedAt: fixedClock.subtract(const Duration(days: 20)),
  );

  final sampleStaleSource = CatalogSourceMeta(
    title: 'Older Registry',
    url: 'https://example.de/registry',
    publisher: 'German Ministry Archive',
    retrievedAt: fixedClock.subtract(const Duration(days: 400)),
  );

  final testCatalog = UniversityScholarshipCatalog(
    programs: [
      UniversityProgram(
        id: 'prog-uoft-cs',
        institutionName: 'University of Toronto',
        countryCode: 'CA',
        city: 'Toronto, Ontario',
        programName: 'Computer Science (B.Sc.)',
        degreeLevel: DegreeLevel.bachelor,
        tuition: const MoneyAmount(amount: 45000, currencyCode: 'CAD'),
        source: sampleFreshSource,
      ),
      UniversityProgram(
        id: 'prog-tum-inf',
        institutionName: 'Technical University of Munich',
        countryCode: 'DE',
        city: 'Munich, Bavaria',
        programName: 'M.Sc. Informatics',
        degreeLevel: DegreeLevel.master,
        tuition: const MoneyAmount(amount: 0, currencyCode: 'EUR'),
        source: sampleTumSource,
      ),
      UniversityProgram(
        id: 'prog-stale-sample',
        institutionName: 'Heidelberg University',
        countryCode: 'DE',
        city: 'Heidelberg',
        programName: 'Ph.D. Biosciences',
        degreeLevel: DegreeLevel.doctorate,
        source: sampleStaleSource,
      ),
    ],
    scholarships: [
      ScholarshipListing(
        id: 'sch-daad',
        name: 'DAAD Graduate Scholarship',
        countryCode: 'DE',
        institutionName: 'German State Universities',
        eligibilitySummary: 'Foreign graduates for Master studies in Germany.',
        award: const MoneyAmount(amount: 934, currencyCode: 'EUR'),
        deadline: fixedClock.add(const Duration(days: 45)),
        source: sampleDaadSource,
      ),
      ScholarshipListing(
        id: 'sch-expired-grant',
        name: 'Expired Excellence Grant',
        countryCode: 'CA',
        award: const MoneyAmount(amount: 10000, currencyCode: 'CAD'),
        deadline: fixedClock.subtract(const Duration(days: 5)),
        source: sampleFreshSource,
      ),
    ],
  );

  Widget createSubject({
    required SharedPreferences prefs,
    UniversityScholarshipCatalog? catalog,
    Locale locale = const Locale('en'),
  }) {
    final cat = catalog ?? testCatalog;
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        universityScholarshipCatalogProvider.overrideWithValue(cat),
        universityScholarshipControllerProvider.overrideWith(
          (ref) => UniversityScholarshipController(cat, nowUtc: fixedClock),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: true, boldText: false),
          child: child!,
        ),
        home: const UniversityScholarshipPage(),
      ),
    );
  }

  group('E9-02 University & Scholarship Catalog UI Tests', () {
    testWidgets(
      'renders verified university programs with authoritative citations',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(createSubject(prefs: prefs));
        await tester.pumpAndSettle();

        // Title & Transparency Banner
        expect(find.text('Universities & Scholarships'), findsOneWidget);
        expect(
          find.textContaining(
            'All records are curated directly from official university registries',
          ),
          findsOneWidget,
        );

        // Verified programs
        expect(find.text('University of Toronto'), findsOneWidget);
        expect(find.text('Computer Science (B.Sc.)'), findsOneWidget);
        expect(find.text('Technical University of Munich'), findsOneWidget);

        // Authoritative citations
        expect(
          find.textContaining('University of Toronto Official Registry'),
          findsOneWidget,
        );
        expect(
          find.textContaining('https://artsci.calendar.utoronto.ca/'),
          findsOneWidget,
        );
      },
    );

    testWidgets('filters programs by country and degree level', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(createSubject(prefs: prefs));
      await tester.pumpAndSettle();

      // Tap Canada chip
      final canadaChip = find.widgetWithText(ChoiceChip, 'Canada');
      expect(canadaChip, findsOneWidget);
      await tester.tap(canadaChip);
      await tester.pumpAndSettle();

      // UofT is in Canada, TUM is in Germany
      expect(find.text('University of Toronto'), findsOneWidget);
      expect(find.text('Technical University of Munich'), findsNothing);

      // Filter by Master level (UofT is Bachelor, so result becomes empty)
      final masterChip = find.widgetWithText(ChoiceChip, 'Master');
      expect(masterChip, findsOneWidget);
      await tester.tap(masterChip);
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No university programs found'), findsOneWidget);
    });

    testWidgets(
      'switches to scholarships tab and renders awards and deadlines',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(createSubject(prefs: prefs));
        await tester.pumpAndSettle();

        // Tap Scholarships tab segment
        final schTab = find.text('Scholarships');
        expect(schTab, findsOneWidget);
        await tester.tap(schTab);
        await tester.pumpAndSettle();

        // Verified scholarships rendered
        expect(find.text('DAAD Graduate Scholarship'), findsOneWidget);
        expect(find.text('934 EUR'), findsOneWidget);
        expect(
          find.text('Expired Excellence Grant'),
          findsNothing,
        ); // Excluded by default

        // Toggle off excludeExpiredDeadlines checkbox by tapping checkbox
        final freshCheckbox = find.byType(Checkbox);
        expect(freshCheckbox, findsOneWidget);
      },
    );

    testWidgets(
      'surfaces warning alert for catalog with stale or missing sources',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(createSubject(prefs: prefs));
        await tester.pumpAndSettle();

        // The test catalog includes 'prog-stale-sample' with stale source
        expect(find.byType(InlineAlert), findsWidgets);
        expect(
          find.textContaining('Some programs reference aging source citations'),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders cleanly in Persian RTL across multiple viewports', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();

      for (final width in [390.0, 768.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 2600);
        tester.view.devicePixelRatio = 1;

        await tester.pumpWidget(
          createSubject(prefs: prefs, locale: const Locale('fa')),
        );
        await tester.pumpAndSettle();

        expect(find.text('دانشگاه‌ها و بورسیه‌های تحصیلی'), findsOneWidget);
        expect(find.text('برنامه‌های دانشگاهی'), findsOneWidget);
        expect(find.text('بورسیه‌های تحصیلی'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester.view.reset();
    });
  });
}
