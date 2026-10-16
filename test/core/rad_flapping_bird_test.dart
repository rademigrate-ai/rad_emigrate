import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/rad_flapping_bird.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'RadFlappingBird articulates the approved wing and body in 6-stage cycle',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RadFlappingBird(
                size: 64,
                semanticLabel: 'Loading bird',
                showAura: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('flapping-bird-wing')), findsOneWidget);
      expect(find.byKey(const ValueKey('flapping-bird-body')), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.bySemanticsLabel('Loading bird'), findsOneWidget);
    },
  );

  testWidgets(
    'RadFlappingBird.button renders compact high-contrast loading state',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RadFlappingBird.button(
                size: 20,
                semanticLabel: 'Submitting',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RadFlappingBird), findsOneWidget);
      final size = tester.getSize(find.byType(RadFlappingBird));
      expect(size.width, 20);
      expect(size.height, 20);
      expect(find.bySemanticsLabel('Submitting'), findsOneWidget);
    },
  );

  testWidgets('reduced motion settles RadFlappingBird at gliding pose', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Scaffold(
              body: Center(
                child: RadFlappingBird(size: 48, semanticLabel: 'Resting bird'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('flapping-bird-wing')), findsOneWidget);
    expect(find.byKey(const ValueKey('flapping-bird-body')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
