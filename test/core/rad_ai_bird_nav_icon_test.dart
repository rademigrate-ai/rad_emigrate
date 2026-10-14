import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/rad_ai_bird_nav_icon.dart';

double _scale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('rad-ai-bird-nav-scale')))
    .transform
    .entry(0, 0);

void main() {
  testWidgets('tap starts the spring response and invokes its callback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: false),
            child: Scaffold(
              body: Center(
                child: RadAiBirdNavIcon(
                  selected: false,
                  label: 'AI Assistant',
                  moreLabel: 'More',
                  onTap: () => taps++,
                  onLongPress: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(RadAiBirdNavIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 45));

    expect(taps, 1);
    expect(_scale(tester), lessThan(1));
  });

  testWidgets('reduced motion suppresses and resets the spring response', (
    tester,
  ) async {
    var taps = 0;
    final disableAnimations = ValueNotifier(false);
    addTearDown(disableAnimations.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: disableAnimations,
          builder: (context, reduceMotion, _) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: Scaffold(
              body: Center(
                child: RadAiBirdNavIcon(
                  selected: false,
                  label: 'AI Assistant',
                  moreLabel: 'More',
                  onTap: () => taps++,
                  onLongPress: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(RadAiBirdNavIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 45));

    expect(taps, 1);
    expect(_scale(tester), lessThan(1));
    disableAnimations.value = true;
    await tester.pump();
    expect(_scale(tester), 1);
    disableAnimations.value = false;
    await tester.pump();
    expect(_scale(tester), 1);
  });
}
