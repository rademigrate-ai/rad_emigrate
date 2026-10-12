import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';
import 'package:rad_emigrate/core/widgets/error_state.dart';
import 'package:rad_emigrate/core/widgets/status_badge.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [320.0, 360.0, 390.0, 768.0, 1280.0]) {
    testWidgets('EQS-A11Y EmptyState no overflow at $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: const TextScaler.linear(1.3),
          ),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: EmptyState(
                title: 'No programmes found for this destination filter',
                subtitle: 'Try changing filters or clearing search',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('EQS-A11Y ErrorState semantics live region at scale 1.6', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 800),
          textScaler: TextScaler.linear(1.6),
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ErrorState(message: 'Catalogue unavailable', onRetry: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Catalogue unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EQS-A11Y StatusBadge semantics include status label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: StatusBadge(label: 'Under Review', tone: StatusTone.warning),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Under Review')), findsWidgets);
  });
}
