import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/constrained_content.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState exposes combined semantics label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: 'No items',
            subtitle: 'Try again later',
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('No items. Try again later'),
      findsOneWidget,
    );
  });

  testWidgets('ConstrainedContent caps child width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConstrainedContent(
            maxWidth: 320,
            child: SizedBox(width: 2000, height: 40, child: Text('wide')),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(find.text('wide'));
    expect(box.size.width, lessThanOrEqualTo(320));
  });
}
