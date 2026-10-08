import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/rad_earth_bird_scene.dart';
import 'package:rad_emigrate/core/widgets/rad_loading.dart';
import 'package:rad_emigrate/core/widgets/premium_visuals.dart';
import 'package:rad_emigrate/features/splash/presentation/pages/splash_page.dart';
import 'package:rad_emigrate/visual_qa_main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester,
  String screen, {
  Size viewport = const Size(1280, 1000),
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = viewport;
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

  testWidgets('visual QA Login retains its default editorial rule', (
    tester,
  ) async {
    await _pump(tester, 'login');

    final canvases = tester.widgetList<PremiumCanvas>(
      find.byType(PremiumCanvas),
    );
    expect(canvases, isNotEmpty);
    expect(canvases.every((canvas) => canvas.showEditorialRule), isTrue);
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

  testWidgets('visual QA Splash route holds the real Splash page pending', (
    tester,
  ) async {
    await _pump(tester, 'splash');

    expect(find.byType(SplashPage), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RadEarthBirdScene &&
            widget.variant == RadEarthBirdVariant.splash,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'loading-full': RadEarthBirdVariant.fullScreenLoading,
    'loading-section': RadEarthBirdVariant.sectionLoading,
    'loading-section-dark': RadEarthBirdVariant.sectionLoading,
  }.entries) {
    testWidgets('visual QA ${entry.key} route presents its approved scene', (
      tester,
    ) async {
      await _pump(tester, entry.key);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadEarthBirdScene && widget.variant == entry.value,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'full-screen visual QA is clean and uses the enlarged Earth scene',
    (tester) async {
      await _pump(tester, 'loading-full');

      expect(find.byType(Banner), findsNothing);
      expect(
        tester
            .widget<PremiumCanvas>(find.byType(PremiumCanvas))
            .showEditorialRule,
        isFalse,
      );
      final scene = find.byWidgetPredicate(
        (widget) =>
            widget is RadEarthBirdScene &&
            widget.variant == RadEarthBirdVariant.fullScreenLoading,
      );
      expect(
        find.descendant(
          of: scene,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.width == 280 &&
                widget.height == 280,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final screen in ['splash', 'loading-full']) {
    testWidgets('visual QA $screen loader suppresses the editorial red rule', (
      tester,
    ) async {
      await _pump(tester, screen);

      expect(
        tester
            .widget<PremiumCanvas>(find.byType(PremiumCanvas))
            .showEditorialRule,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'full-screen loader scales down only when narrow width requires it',
    (tester) async {
      await _pump(tester, 'loading-full', viewport: const Size(320, 844));

      final scene = find.byWidgetPredicate(
        (widget) =>
            widget is RadEarthBirdScene &&
            widget.variant == RadEarthBirdVariant.fullScreenLoading,
      );
      expect(
        find.descendant(
          of: scene,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.width == 272 &&
                widget.height == 272,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full-screen loader preserves the 280 px scene at 390 px mobile',
    (tester) async {
      await _pump(tester, 'loading-full', viewport: const Size(390, 844));

      final scene = find.byWidgetPredicate(
        (widget) =>
            widget is RadEarthBirdScene &&
            widget.variant == RadEarthBirdVariant.fullScreenLoading,
      );
      expect(
        find.descendant(
          of: scene,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.width == 280 &&
                widget.height == 280,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dark section QA title uses explicit readable foreground color', (
    tester,
  ) async {
    await _pump(tester, 'loading-section-dark');

    final title = tester.widget<Text>(find.text('Section loading'));
    expect(title.style?.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'visual QA compact route presents light and dark loading states',
    (tester) async {
      await _pump(tester, 'loading-compact');

      expect(
        find.byWidgetPredicate(
          (widget) => widget is RadInlineLoading && !widget.dark,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RadInlineLoading && widget.dark,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RadEarthBirdScene &&
              widget.variant == RadEarthBirdVariant.compactLoading,
        ),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
