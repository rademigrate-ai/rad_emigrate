import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/pathway_comparison/data/pathway_comparison_repository.dart';
import 'package:rad_emigrate/features/pathway_comparison/domain/entities/pathway_comparison.dart';
import 'package:rad_emigrate/features/pathway_comparison/presentation/pages/pathway_comparison_page.dart';
import 'package:rad_emigrate/features/pathway_comparison/presentation/providers/pathway_comparison_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  group('Pathway Comparison Domain Tests', () {
    test('returns comparison items for Germany and Canada', () async {
      const repo = StaticPathwayComparisonRepository();
      final items = await repo.getComparisonItems(locale: 'fa');

      expect(items.length, 3);
      expect(items.any((e) => e.countryCode == 'DE'), isTrue);
      expect(items.any((e) => e.countryCode == 'CA'), isTrue);
      expect(items.any((e) => e.countryCode == 'AU'), isTrue);
    });
  });

  group('PathwayComparisonPage Widget Tests', () {
    testWidgets('renders pathway comparison cards properly in Persian', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('fa'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PathwayComparisonPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('مقایسه مسیرهای مهاجرتی'), findsOneWidget);
      expect(find.text('آلمان'), findsOneWidget);
      expect(find.text('کانادا'), findsOneWidget);
      expect(find.text('استرالیا'), findsOneWidget);
      expect(find.text('اقامت دائم مستقیم'), findsNWidgets(2)); // CA and AU
    });
  });
}
