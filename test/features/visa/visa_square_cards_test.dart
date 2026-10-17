import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/theme/app_theme.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/visa_page.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/visa_catalog_provider.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  for (final locale in ['en', 'fa']) {
    for (final width in [280.0, 390.0, 744.0, 1200.0]) {
      testWidgets('$locale full Visa cards remain square at $width', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1200);
        addTearDown(tester.view.reset);
        final catalog = VisaCatalog(
          countries: [
            for (final code in ['AE', 'OM', 'NO', 'MY'])
              Country(
                id: code,
                name: locale == 'fa'
                    ? 'نام بلند کشور مقصد $code'
                    : 'Long destination name $code',
                code: code,
                flagEmoji: '🌐',
                slug: code.toLowerCase(),
              ),
          ],
          categories: const [],
          programs: const [],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              visaCatalogProvider(locale).overrideWith((_) async => catalog),
            ],
            child: MaterialApp(
              theme: AppTheme.dark(),
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const VisaPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final a = tester.getRect(
          find.byKey(const ValueKey('destination-card-AE')),
        );
        final b = tester.getRect(
          find.byKey(const ValueKey('destination-card-OM')),
        );
        expect(a.width, closeTo(a.height, .01));
        expect(b.width, closeTo(b.height, .01));
        if (width >= 336 && width <= 744) {
          expect(a.top, b.top);
          expect(
            tester
                .getRect(find.byKey(const ValueKey('destination-card-NO')))
                .top,
            greaterThan(a.bottom),
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
