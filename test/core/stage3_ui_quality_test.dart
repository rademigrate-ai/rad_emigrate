import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/constrained_content.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState exposes combined semantics label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(title: 'No items', subtitle: 'Try again later'),
        ),
      ),
    );

    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('No items. Try again later'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('ConstrainedContent applies max width constraint', (
    tester,
  ) async {
    const childKey = Key('constrained-child');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConstrainedContent(
            maxWidth: 320,
            padding: EdgeInsets.zero,
            child: SizedBox(key: childKey, width: 800, height: 24),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(childKey)).width, 320);
  });
}
