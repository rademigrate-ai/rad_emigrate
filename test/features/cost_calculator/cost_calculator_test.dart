import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/cost_calculator/data/cost_calculator_repository.dart';
import 'package:rad_emigrate/features/cost_calculator/presentation/pages/cost_calculator_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  group('Cost Calculator Domain Tests', () {
    test('returns empty items when official catalog unavailable', () async {
      const repo = StaticCostCalculatorRepository();
      final result = await repo.calculatePathwayCosts(
        countryCode: 'DE',
        pathwaySlug: 'chancenkarte',
        applicantsCount: 2,
        locale: 'fa',
      );
      expect(result.countryCode, 'DE');
      expect(result.items, isEmpty);
      expect(result.totalMandatoryAmount, 0.0);
      expect(result.disclaimer.isNotEmpty, isTrue);
    });

    test('does not invent Canadian fees offline', () async {
      const repo = StaticCostCalculatorRepository();
      final result = await repo.calculatePathwayCosts(
        countryCode: 'CA',
        pathwaySlug: 'express-entry',
        applicantsCount: 1,
        locale: 'en',
      );
      expect(result.countryCode, 'CA');
      expect(result.items, isEmpty);
      expect(result.totalMandatoryAmount, 0.0);
    });
  });

  group('CostCalculatorPage Widget Tests', () {
    testWidgets('renders page without fabricated fee amounts', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CostCalculatorPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CostCalculatorPage), findsOneWidget);
      expect(find.text('75 EUR'), findsNothing);
      expect(find.text('150 EUR'), findsNothing);
    });
  });
}
