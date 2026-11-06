import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/visa_page.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/visa_catalog_provider.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  final catalog = VisaCatalog(
    countries: const [
      Country(
        id: 'canada-id',
        name: 'Canada',
        code: 'CA',
        flagEmoji: '🇨🇦',
        slug: 'canada',
      ),
    ],
    categories: const [],
    programs: const [],
  );

  Widget root({
    required VisaCatalog destinations,
    required List<Map<String, dynamic>> published,
  }) {
    final router = GoRouter(
      initialLocation: '/visa',
      routes: [
        GoRoute(path: '/visa', builder: (_, _) => const VisaPage()),
        GoRoute(
          path: '/visa/content-countries/:countryCode',
          builder: (_, state) => Scaffold(
            body: Text(
              'Published country ${state.pathParameters['countryCode']}',
            ),
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        visaCatalogProvider('en').overrideWith((_) async => destinations),
        visaContentCountriesProvider('en').overrideWith((_) async => published),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets(
    'published editorial-only countries become real Visa photo cards',
    (tester) async {
      tester.view.physicalSize = const Size(960, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        root(
          destinations: catalog,
          published: [
            {'country_code': 'CA'},
            {'country_code': 'FI'},
            {'country_code': 'FI'},
            {'country_code': 'XX-INVALID'},
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Published content must not replace the original country photo cards
      // with the legacy text-only country list.
      expect(
        find.byKey(const ValueKey('destination-card-canada-id')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('destination-card-editorial-CA')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('destination-card-editorial-FI')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('destination-card-editorial-XX-INVALID')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('destination-card-editorial-FI')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Published country FI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('countries from published Visa content survive empty catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      root(
        destinations: const VisaCatalog(
          countries: [],
          categories: [],
          programs: [],
        ),
        published: [
          {'country_code': 'SE'},
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('destination-card-editorial-SE')),
      findsOneWidget,
    );
    expect(find.text('Sweden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no published records means no editorial-only cards', (
    tester,
  ) async {
    await tester.pumpWidget(root(destinations: catalog, published: []));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('destination-card-canada-id')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('destination-card-editorial-FI')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
