import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/rad_earth_bird_scene.dart';
import 'package:rad_emigrate/core/widgets/rad_loading.dart';
import 'package:rad_emigrate/visual_qa_main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, String screen) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    VisualQaApp(preferences: preferences, initialScreen: screen),
  );
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  for (final screen in ['login', 'dashboard', 'visa', 'ai', 'feed', 'admin']) {
    testWidgets('visual QA $screen composition builds', (tester) async {
      await _pump(tester, screen);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('visual QA login uses the premium Earth and bird scene', (
    tester,
  ) async {
    await _pump(tester, 'login');

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RadEarthBirdScene &&
            widget.variant == RadEarthBirdVariant.loginHero,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('visual QA loading composition presents every RAD loading tier', (
    tester,
  ) async {
    await _pump(tester, 'loading');

    expect(find.byType(RadLoadingIndicator), findsNWidgets(3));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RadLoadingIndicator &&
            widget.size == RadLoadingSize.fullScreen,
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
    expect(tester.takeException(), isNull);
  });
}
