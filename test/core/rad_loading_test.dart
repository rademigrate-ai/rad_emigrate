import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/rad_loading.dart';

void main() {
  testWidgets('full-screen RAD loader exposes a live loading label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadLoadingIndicator(
            size: RadLoadingSize.fullScreen,
            label: 'Loading your RAD journey',
            message: 'Preparing your secure workspace',
          ),
        ),
      ),
    );

    expect(find.byType(RadLoadingIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading your RAD journey'), findsOneWidget);
    expect(find.text('Preparing your secure workspace'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('section and compact loaders preserve their declared tier', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              RadLoadingIndicator(
                size: RadLoadingSize.section,
                label: 'Loading cases',
              ),
              RadInlineLoading(label: 'Updating case status'),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RadLoadingIndicator &&
            widget.size == RadLoadingSize.section,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RadLoadingIndicator &&
            widget.size == RadLoadingSize.compact,
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Updating case status'), findsOneWidget);
  });

  testWidgets('reduced motion keeps the branded loader readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: RadLoadingIndicator(
              size: RadLoadingSize.section,
              label: 'Loading documents',
              message: 'Checking your documents',
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 3));

    expect(find.bySemanticsLabel('Loading documents'), findsOneWidget);
    expect(find.text('Checking your documents'), findsOneWidget);
  });

  testWidgets('inactive loader still renders a static progress identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadLoadingIndicator(
            size: RadLoadingSize.compact,
            label: 'Saving profile',
            active: false,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));

    expect(find.bySemanticsLabel('Saving profile'), findsOneWidget);
  });
}
