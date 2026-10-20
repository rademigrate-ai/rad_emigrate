import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/university_comparison/data/university_comparison_repository.dart';
import 'package:rad_emigrate/features/university_comparison/domain/entities/university_comparison.dart';
import 'package:rad_emigrate/features/university_comparison/presentation/pages/university_comparison_page.dart';
import 'package:rad_emigrate/features/university_comparison/presentation/providers/university_comparison_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  group('University Comparison Domain Tests', () {
    test('filters universities by country code', () async {
      const repo = StaticUniversityComparisonRepository();
      final all = await repo.getUniversities(locale: 'fa');
      final germany = await repo.getUniversities(
        countryFilter: 'DE',
        locale: 'fa',
      );

      expect(all.length, 3);
      expect(germany.length, 1);
      expect(germany.first.countryCode, 'DE');
      expect(germany.first.id, 'tum');
    });
  });

  group('UniversityComparisonPage Widget Tests', () {
    testWidgets('renders university comparison cards and filters properly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('fa'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: UniversityComparisonPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('مقایسه دانشگاه‌ها و بورسیه‌ها'), findsOneWidget);
      expect(find.text('دانشگاه فنی مونیخ (TUM)'), findsOneWidget);
      expect(find.text('دانشگاه تورنتو (U of T)'), findsOneWidget);
      expect(find.text('دانشگاه ملبورن'), findsOneWidget);

      // Filter by Germany
      await tester.tap(find.text('آلمان'));
      await tester.pumpAndSettle();

      expect(find.text('دانشگاه فنی مونیخ (TUM)'), findsOneWidget);
      expect(find.text('دانشگاه تورنتو (U of T)'), findsNothing);
      expect(find.text('دانشگاه ملبورن'), findsNothing);
    });
  });
}
