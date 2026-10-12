import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/error_state.dart';
import 'package:rad_emigrate/core/widgets/loading_state.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/visa_page.dart';
import 'package:rad_emigrate/features/visa/presentation/providers/visa_catalog_provider.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

Future<void> frames(WidgetTester t, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

VisaCatalog sampleCatalog() {
  final src = VisaSource(
    title: 'src',
    url: 'https://example.test/s',
    publisher: 'RAD',
    retrievedAt: DateTime.utc(2026, 1, 1),
  );
  return VisaCatalog(
    countries: const [
      Country(
        id: 'ca',
        name: 'Canada',
        code: 'CA',
        flagEmoji: '🇨🇦',
        slug: 'canada',
      ),
    ],
    categories: const [
      VisaCategory(id: 'study', name: 'Study', description: 'd', slug: 'study'),
    ],
    programs: [
      VisaProgram(
        id: 'p1',
        slug: 'ca-study',
        title: 'Canada Study',
        countryId: 'ca',
        categoryId: 'study',
        summary: 'Summary for test program',
        source: src,
        requirements: const [VisaRequirement(text: 'Funds', displayOrder: 1)],
        steps: const [
          VisaStep(title: 'Apply', description: '', displayOrder: 1),
        ],
      ),
    ],
  );
}

Widget app(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const VisaPage(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EQS-VISA loading shows LoadingState', (tester) async {
    final c = Completer<VisaCatalog>();
    await tester.pumpWidget(
      app([visaCatalogProvider.overrideWith((ref, l) => c.future)]),
    );
    await tester.pump();
    expect(find.byType(LoadingState), findsWidgets);
    c.complete(sampleCatalog());
    await frames(tester);
  });

  testWidgets('EQS-VISA error shows ErrorState with retry', (tester) async {
    await tester.pumpWidget(
      app([
        visaCatalogProvider.overrideWith((ref, locale) async {
          throw Exception('network');
        }),
      ]),
    );
    await frames(tester, 20);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(
      find.text(lookupAppLocalizations(const Locale('en')).retry),
      findsOneWidget,
    );
  });

  testWidgets('EQS-VISA data lists programme titles', (tester) async {
    // Tall surface so the catalogue ListView can paint program cards below
    // the hero + filter chrome (default 800x600 was insufficient in practice).
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app([
        visaCatalogProvider.overrideWith(
          (ref, locale) async => sampleCatalog(),
        ),
      ]),
    );
    await frames(tester, 40);

    expect(
      find.text('Canada Study'),
      findsOneWidget,
      reason: 'Visa list must render VisaProgram.title from catalog fixture',
    );
    expect(find.text('Summary for test program'), findsOneWidget);
  });
}
