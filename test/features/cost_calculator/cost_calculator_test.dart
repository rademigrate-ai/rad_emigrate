import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/cost_calculator/data/cost_calculator_repository.dart';
import 'package:rad_emigrate/features/cost_calculator/domain/entities/cost_estimate.dart';
import 'package:rad_emigrate/features/cost_calculator/presentation/pages/cost_calculator_page.dart';
import 'package:rad_emigrate/features/cost_calculator/presentation/providers/cost_calculator_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  group('Cost Calculator Domain Tests', () {
    test('calculates correct totals for Germany Chancenkarte', () async {
      const repo = StaticCostCalculatorRepository();
      final result = await repo.calculatePathwayCosts(
        countryCode: 'DE',
        pathwaySlug: 'chancenkarte',
        applicantsCount: 2,
        locale: 'fa',
      );

      expect(result.countryCode, 'DE');
      expect(result.baseCurrency, 'EUR');
      // Government fee: 75 * 2 = 150
      expect(result.totalMandatoryAmount, 150.0);
      expect(result.settlementFundsAmount, 12324.0);
    });

    test('calculates correct totals for Canada Express Entry', () async {
      const repo = StaticCostCalculatorRepository();
      final result = await repo.calculatePathwayCosts(
        countryCode: 'CA',
        pathwaySlug: 'express-entry',
        applicantsCount: 1,
        locale: 'en',
      );

      expect(result.countryCode, 'CA');
      expect(result.baseCurrency, 'CAD');
      // 950 + 575 + 85 = 1610
      expect(result.totalMandatoryAmount, 1610.0);
      expect(result.settlementFundsAmount, 14690.0);
    });
  });

  group('CostCalculatorPage Widget Tests', () {
    testWidgets(
      'renders cost breakdown and updates on applicant count change',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              locale: Locale('fa'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: CostCalculatorPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('محاسبه‌گر هزینه‌های مهاجرت'), findsOneWidget);
        expect(find.text('کارت شانس (Chancenkarte)'), findsOneWidget);
        expect(find.text('تعرفه صدور روادید کارت شانس'), findsOneWidget);
        expect(find.text('75 EUR'), findsNWidgets(2));

        // Increase applicant count to 2
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();

        expect(find.text('2'), findsOneWidget);
        expect(find.text('150 EUR'), findsNWidgets(2));
      },
    );
  });
}
