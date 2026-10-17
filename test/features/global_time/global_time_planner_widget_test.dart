import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/theme/app_theme.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';
import 'package:rad_emigrate/features/global_time/domain/city_catalog.dart';
import 'package:rad_emigrate/features/global_time/domain/timezone_engine.dart';
import 'package:rad_emigrate/features/global_time/presentation/widgets/meeting_planner_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => TimezoneEngine.ensureInitialized());
  for (final language in ['en', 'fa']) {
    testWidgets(
      '$language planner accepts time/date and exposes real converted zones',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MeetingPlannerPanel(
                  cities: CityCatalog.defaults,
                  languageCode: language,
                ),
              ),
            ),
          ),
        );
        expect(find.byKey(const ValueKey('meeting-time')), findsOneWidget);
        expect(find.byKey(const ValueKey('meeting-date')), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('meeting-convert')),
        );
        await tester.tap(find.byKey(const ValueKey('meeting-convert')));
        await tester.pump();
        expect(find.textContaining('Asia/Tehran'), findsOneWidget);
        expect(find.textContaining('America/Toronto'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
