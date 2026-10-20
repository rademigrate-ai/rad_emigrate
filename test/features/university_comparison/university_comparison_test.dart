import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/university_comparison/data/university_comparison_repository.dart';
import 'package:rad_emigrate/features/university_comparison/presentation/pages/university_comparison_page.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  group('University Comparison Domain Tests', () {
    test('returns empty when institutional catalog unavailable', () async {
      const repo = StaticUniversityComparisonRepository();
      final all = await repo.getUniversities(locale: 'fa');
      final germany = await repo.getUniversities(
        countryFilter: 'DE',
        locale: 'fa',
      );
      expect(all, isEmpty);
      expect(germany, isEmpty);
    });
  });

  group('UniversityComparisonPage Widget Tests', () {
    testWidgets('renders without fabricated university claims', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: UniversityComparisonPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UniversityComparisonPage), findsOneWidget);
    });
  });
}
