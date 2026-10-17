import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/rad_ai_bird.dart';

void main() {
  for (final state in RadAiBirdState.values) {
    testWidgets('${state.name} has a stable accessible representation', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: RadAiBird(
                    state: state,
                    semanticLabel: 'Assistant ${state.name}',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final node = tester.getSemantics(find.byType(RadAiBird));
      expect(node.label, 'Assistant ${state.name}');
      expect(node.flagsCollection.isImage, isTrue);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('motion mode articulates both wings around the original body', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadAiBird(
            state: RadAiBirdState.responding,
            semanticLabel: 'Assistant responding',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey('articulated-rad-bird')), findsOneWidget);
    expect(find.byKey(const ValueKey('rad-bird-left-wing')), findsOneWidget);
    expect(find.byKey(const ValueKey('rad-bird-right-wing')), findsOneWidget);
    expect(find.byKey(const ValueKey('rad-bird-body')), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
