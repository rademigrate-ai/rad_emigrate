import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';
import 'package:rad_emigrate/core/widgets/error_state.dart';
import 'package:rad_emigrate/core/widgets/loading_state.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UJ09 EmptyState shows title subtitle and optional action', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        EmptyState(
          title: 'No programmes found',
          subtitle: 'Try changing filters',
          actionLabel: 'Reset',
          onAction: () => tapped = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No programmes found'), findsOneWidget);
    expect(find.text('Try changing filters'), findsOneWidget);
    expect(
      find.bySemanticsLabel('No programmes found. Try changing filters'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('UJ09b ErrorState exposes live region and retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _app(
        ErrorState(message: 'Catalogue unavailable', onRetry: () => retries++),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Catalogue unavailable'), findsOneWidget);
    expect(find.bySemanticsLabel('Catalogue unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('UJ09c LoadingState section renders without exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(LoadingState.section(message: 'Loading catalogue…')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text('Loading catalogue…'), findsOneWidget);
  });
}
