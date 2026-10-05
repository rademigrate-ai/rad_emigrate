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

  testWidgets('ConstrainedContent applies max width constraint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConstrainedContent(
            maxWidth: 320,
            padding: EdgeInsets.zero,
            child: Builder(
              builder: (context) {
                final max = context
                    .findAncestorRenderObjectOfType<RenderConstrainedBox>()
                    ?.constraints
                    .maxWidth;
                return Text('max=$max');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('max=320'), findsOneWidget);
  });
}
