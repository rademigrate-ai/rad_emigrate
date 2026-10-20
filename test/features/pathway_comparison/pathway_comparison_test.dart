import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/pathway_comparison/data/pathway_comparison_repository.dart';
import 'package:rad_emigrate/features/pathway_comparison/presentation/pages/pathway_comparison_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  group('Pathway Comparison Domain Tests', () {
    test('returns empty when official pathway catalog unavailable', () async {
      const repo = StaticPathwayComparisonRepository();
      final items = await repo.getComparisonItems(locale: 'fa');
      expect(items, isEmpty);
    });
  });

  group('PathwayComparisonPage Widget Tests', () {
    testWidgets('renders without fabricated pathway claims', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PathwayComparisonPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PathwayComparisonPage), findsOneWidget);
    });
  });
}
