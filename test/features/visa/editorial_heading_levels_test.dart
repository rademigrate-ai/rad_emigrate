import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/editorial_rich_block.dart';

void main() {
  testWidgets(
    'raw-backed supplemental heading level survives immutable structure unwrapping',
    (tester) async {
      final original = {'type': 'heading', 'text': 'Captured level three'};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorialRichBlock(
              block: {
                'type': 'heading',
                'text': 'Captured level three',
                'original_structure': original,
                'heading_level': 3,
              },
            ),
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.headingLevel == 3,
        ),
        findsOneWidget,
      );
      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(
        text.style?.fontSize,
        Theme.of(tester.element(find.text('Captured level three')))
            .textTheme
            .titleLarge
            ?.fontSize,
      );
      expect(original, {'type': 'heading', 'text': 'Captured level three'});
    },
  );

  testWidgets(
    'explicit current heading structure retains precedence over original supplemental metadata',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditorialRichBlock(
              block: {
                'type': 'heading',
                'text': 'Original heading',
                'heading_level': 2,
                'original_structure': {
                  'type': 'heading',
                  'text': 'Original heading',
                },
                'current_structure': {
                  'type': 'heading',
                  'text': 'Reviewed fourth-level heading',
                  'level': 4,
                },
              },
            ),
          ),
        ),
      );
      expect(find.text('Reviewed fourth-level heading'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.headingLevel == 4,
        ),
        findsOneWidget,
      );
      expect(find.text('Original heading'), findsNothing);
    },
  );
}
