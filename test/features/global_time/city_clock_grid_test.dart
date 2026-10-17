import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/theme/app_theme.dart';
import 'package:rad_emigrate/features/global_time/domain/city_catalog.dart';
import 'package:rad_emigrate/features/global_time/domain/timezone_engine.dart';
import 'package:rad_emigrate/features/global_time/presentation/widgets/city_clock_card.dart';
import 'package:rad_emigrate/features/global_time/presentation/widgets/city_clock_grid.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TimezoneEngine.ensureInitialized);
  for (final locale in ['fa', 'en']) {
    for (final width in [280.0, 320.0, 390.0, 744.0, 1200.0]) {
      testWidgets(
        '$locale clock grid at $width retains clocks and usable columns',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1200);
          addTearDown(tester.view.reset);
          final cities = CityCatalog.defaults.take(4).toList();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark(),
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CityClockGrid(
                      cities: cities,
                      languageCode: locale,
                      atUtc: DateTime.utc(2026, 10, 17, 12),
                      onSelect: (_) {},
                      onRemove: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final cards = find.byType(CityClockCard);
          final a = tester.getRect(cards.at(0));
          final b = tester.getRect(cards.at(1));
          if (width >= 336 && width < 832) {
            expect(b.top, a.top);
            expect((b.center.dx - a.center.dx).abs(), greaterThan(a.width));
            expect(tester.getRect(cards.at(2)).top, greaterThan(a.bottom));
          } else if (width <= 320) {
            expect(b.top, greaterThan(a.bottom));
          }
          expect(
            find.text('15:30'),
            findsOneWidget,
          ); // Tehran, same computed instant
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('large type falls back to one mobile column without clipping', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CityClockGrid(
              cities: CityCatalog.defaults.take(2).toList(),
              languageCode: 'en',
              atUtc: DateTime.utc(2026, 10, 17),
              onSelect: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getRect(find.byType(CityClockCard).at(1)).top,
      greaterThan(tester.getRect(find.byType(CityClockCard).first).bottom),
    );
    expect(tester.takeException(), isNull);
  });
}
