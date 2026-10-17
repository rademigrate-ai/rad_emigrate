import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/loading_state.dart';
import 'package:rad_emigrate/core/widgets/motion_primitives.dart';
import 'package:rad_emigrate/core/widgets/rad_loading.dart';
import 'package:rad_emigrate/core/widgets/rad_flapping_bird.dart';
import 'package:rad_emigrate/core/widgets/app_button.dart';

void main() {
  test('web bootstrap shares original identity and one localized status without a spinner', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('rad_flying_bird_1024.png'));
    expect(html, isNot(contains('rad_phoenix_final')));
    expect(html, isNot(contains('rad-startup-spinner')));
    expect(html, contains('prefers-reduced-motion'));
    expect(RegExp(r'<p id="rad-startup-message"').allMatches(html).length, 1);
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      expect(
        file.readAsStringSync(),
        isNot(contains('CircularProgressIndicator(')),
        reason: file.path,
      );
    }
  });
  testWidgets(
    'splash loading paints no rectangular background over its parent scene',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingState.splash(
              semanticsLabel: 'Loading',
              message: 'Loading',
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(LoadingState),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      expect(find.byType(RadFlappingBird), findsOneWidget);
    },
  );

  testWidgets(
    'pending buttons retain original colors and reject duplicate submission',
    (tester) async {
      var submissions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Submit request',
              loading: true,
              onPressed: () => submissions++,
            ),
          ),
        ),
      );
      final bird = tester.widget<RadFlappingBird>(find.byType(RadFlappingBird));
      expect(
        bird.color,
        isNull,
        reason: 'Pending feedback preserves the layered red artwork',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(submissions, 0);
    },
  );
  testWidgets('full-screen RAD loader exposes one live loading label', (
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
    expect(
      tester.getSemantics(find.byType(RadLoadingIndicator)),
      matchesSemantics(label: 'Loading your RAD journey', isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets(
    'loading adapter maps every tier to the approved natural wingbeat',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RadLoadingIndicator(
                  size: RadLoadingSize.fullScreen,
                  label: 'Loading RAD workspace',
                ),
                RadLoadingIndicator(
                  size: RadLoadingSize.section,
                  label: 'Loading applications',
                ),
                RadInlineLoading(label: 'Updating application'),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is RadFlappingBird && widget.size == 128,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RadFlappingBird && widget.size == 72,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RadFlappingBird && widget.size == 32,
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(
          find.byWidgetPredicate(
            (widget) =>
                widget is RadLoadingIndicator &&
                widget.size == RadLoadingSize.fullScreen,
          ),
        ),
        matchesSemantics(label: 'Loading RAD workspace', isLiveRegion: true),
      );
      semantics.dispose();
    },
  );

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

  testWidgets(
    'reduced motion stops the loader ticker and keeps copy readable',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
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

      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('Loading documents'), findsOneWidget);
      expect(find.text('Checking your documents'), findsOneWidget);
    },
  );

  testWidgets('inactive loader stops after an active to inactive update', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadLoadingIndicator(
            size: RadLoadingSize.compact,
            label: 'Saving profile',
          ),
        ),
      ),
    );

    expect(tester.hasRunningAnimations, isTrue);

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
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
    expect(find.bySemanticsLabel('Saving profile'), findsOneWidget);
  });

  testWidgets('disabled ticker mode stops an already active loader', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadLoadingIndicator(
            size: RadLoadingSize.section,
            label: 'Loading applications',
          ),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(
          enabled: false,
          child: Scaffold(
            body: RadLoadingIndicator(
              size: RadLoadingSize.section,
              label: 'Loading applications',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('removing a running loader disposes its animation cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadLoadingIndicator(
            size: RadLoadingSize.section,
            label: 'Loading feed',
          ),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shared loading separates display copy from its live announcement',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingState.fullScreen(
              message: 'Preparing the secure RAD workspace',
              semanticsLabel: 'Loading RAD workspace',
            ),
          ),
        ),
      );

      expect(find.text('Preparing the secure RAD workspace'), findsOneWidget);
      expect(find.bySemanticsLabel('Loading RAD workspace'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(LoadingState)),
        matchesSemantics(label: 'Loading RAD workspace', isLiveRegion: true),
      );
      semantics.dispose();
    },
  );

  testWidgets('shared loading states select their declared RAD tier', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: LoadingState.fullScreen(
                  message: 'Bootstrapping RAD',
                  semanticsLabel: 'Loading RAD',
                ),
              ),
              Expanded(
                child: LoadingState.section(
                  message: 'Loading applications',
                  semanticsLabel: 'Loading applications',
                ),
              ),
              LoadingState.compact(
                message: 'Updating application',
                semanticsLabel: 'Updating application',
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is LoadingState &&
              widget.size == RadLoadingSize.fullScreen,
        ),
        matching: find.byType(AppSkeleton),
      ),
      findsNothing,
      reason:
          'Full-screen loading centers the bird; skeletons belong to sections',
    );
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
  });

  testWidgets(
    'Splash loading selects the premium splash scene without a skeleton',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingState.splash(
              message: 'Preparing your RAD workspace',
              semanticsLabel: 'Loading RAD workspace',
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is RadFlappingBird && widget.size == 128,
        ),
        findsOneWidget,
      );
      expect(find.text('Preparing your RAD workspace'), findsOneWidget);
      expect(find.byType(AppSkeleton), findsNothing);
    },
  );
}
