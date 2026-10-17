import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/core/theme/app_theme.dart';
import 'package:rad_emigrate/core/widgets/app_back_button.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/visa_catalog_provider.dart';
import 'package:rad_emigrate/features/visa/presentation/visa_routes.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

const country = Country(
  id: 'country-ca',
  name: 'Canada',
  code: 'CA',
  flagEmoji: '🇨🇦',
  slug: 'canada',
);
final catalog = VisaCatalog(
  countries: [country],
  categories: const [
    VisaCategory(id: 'study', name: 'Study', description: '', slug: 'study'),
  ],
  programs: [
    VisaProgram(
      id: 'program-study',
      slug: 'study',
      title: 'Reviewed study program',
      countryId: country.id,
      categoryId: 'study',
      summary: 'Fixture content',
      source: VisaSource(
        title: 'Test source',
        url: 'https://example.test',
        publisher: 'Fixture',
        retrievedAt: DateTime.utc(2026),
      ),
    ),
  ],
);

Future<GoRouter> pumpRoutes(
  WidgetTester tester,
  String locale,
  String initial,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('home-root')),
      ),
      visaRoute(),
      GoRoute(
        path: '/secondary',
        builder: (_, _) => BackFallbackScope(
          fallback: '/dashboard',
          child: Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallback: '/dashboard'),
            ),
            body: const Text('secondary'),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        visaCatalogProvider('en').overrideWith((_) async => catalog),
        visaCatalogProvider('fa').overrideWith((_) async => catalog),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final locale in ['fa', 'en']) {
    testWidgets(
      '$locale Back pops actual history and direct entry uses fallback',
      (tester) async {
        final router = await pumpRoutes(tester, locale, '/dashboard');
        router.push('/secondary');
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(AppBackButton)).shortestSide,
          greaterThanOrEqualTo(48),
        );
        expect(
          Directionality.of(tester.element(find.byType(BackButtonIcon))),
          locale == 'fa' ? TextDirection.rtl : TextDirection.ltr,
        );
        await tester.tap(find.byType(AppBackButton));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/dashboard');
        router.go('/secondary');
        await tester.pumpAndSettle();
        expect(router.canPop(), isFalse);
        await tester.tap(find.byType(AppBackButton));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/dashboard');
        router.go('/secondary');
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/dashboard');
      },
    );

    testWidgets(
      '$locale Visa deep links and system Back return through real detail routes',
      (tester) async {
        final router = await pumpRoutes(
          tester,
          locale,
          '/visa/country-ca/programs/program-study',
        );
        expect(find.text('Reviewed study program'), findsWidgets);
        expect(router.canPop(), isTrue);
        await tester.tap(find.byType(AppBackButton).last);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/visa/country-ca',
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/visa');
        expect(find.byType(AppBackButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$locale invalid Visa detail remains escapable', (
      tester,
    ) async {
      final router = await pumpRoutes(tester, locale, '/visa/stale-id');
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/visa');
      expect(tester.takeException(), isNull);
    });
  }
}
