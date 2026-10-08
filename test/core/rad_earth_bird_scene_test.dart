import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/rad_earth_bird_scene.dart';

void main() {
  testWidgets(
    'Login Hero scene exposes one semantic label and runs when active',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RadEarthBirdScene(
              variant: RadEarthBirdVariant.loginHero,
              semanticLabel: 'RAD Earth and bird',
              size: 320,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('RAD Earth and bird'), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
      semantics.dispose();
    },
  );

  testWidgets('scene keeps a stable composition when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: RadEarthBirdScene(
              variant: RadEarthBirdVariant.loginHero,
              semanticLabel: 'RAD Earth and bird',
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));

    expect(tester.hasRunningAnimations, isFalse);
    expect(find.bySemanticsLabel('RAD Earth and bird'), findsOneWidget);
  });

  testWidgets('scene stops its ticker when deactivated', (tester) async {
    const scene = RadEarthBirdScene(
      variant: RadEarthBirdVariant.loginHero,
      semanticLabel: 'RAD Earth and bird',
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: scene)));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadEarthBirdScene(
            variant: RadEarthBirdVariant.loginHero,
            semanticLabel: 'RAD Earth and bird',
            active: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('scene stops when its ticker subtree is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadEarthBirdScene(
            variant: RadEarthBirdVariant.loginHero,
            semanticLabel: 'RAD Earth and bird',
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
            body: RadEarthBirdScene(
              variant: RadEarthBirdVariant.loginHero,
              semanticLabel: 'RAD Earth and bird',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('removing the scene disposes the running controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadEarthBirdScene(
            variant: RadEarthBirdVariant.loginHero,
            semanticLabel: 'RAD Earth and bird',
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
}
