import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/theme/app_motion.dart';
import 'package:rad_emigrate/core/widgets/motion_primitives.dart';

void main() {
  testWidgets('MotionReveal renders immediately with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(body: MotionReveal(child: Text('Accessible content'))),
        ),
      ),
    );

    expect(find.text('Accessible content'), findsOneWidget);
  });

  testWidgets('MotionCount never substitutes a value while data is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MotionCount(value: null, placeholder: '—')),
      ),
    );

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('motion tokens collapse duration for reduced motion', (
    tester,
  ) async {
    Duration? observed;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            observed = AppMotion.duration(context, AppMotion.cardEntrance);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(observed, Duration.zero);
  });
}
