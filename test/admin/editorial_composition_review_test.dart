import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/editorial_composition_review.dart';

void main() {
  testWidgets(
    'composition review explains retained passages, semantic equivalents and conflicts',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditorialCompositionReview(
                locale: 'en',
                composition: {
                  'sections': [
                    {
                      'heading': 'Clinical explanation',
                      'blocks': [
                        {
                          'id': 'retained-clinical',
                          'type': 'paragraph',
                          'text': 'Original clinical explanation',
                          'source_role': 'primary',
                          'selected_origin': {
                            'publisher': 'radvisa.com',
                            'url': 'https://radvisa.com/clinical',
                          },
                          'passage_classification': 'specialist_medical',
                          'provenance': [
                            {
                              'url': 'https://radvisa.com/clinical',
                              'snapshot_id': 'snapshot-one',
                              'sha256': 'immutable-hash',
                            },
                          ],
                        },
                      ],
                    },
                  ],
                  'omissions': [
                    {
                      'reason': 'semantic_equivalent_v4',
                      'represented_block_id': 'retained-clinical',
                      'provenance': {'url': 'https://digivisa.ir/comparison'},
                    },
                  ],
                  'conflicts': [
                    {
                      'heading': 'Different thresholds',
                      'resolution': 'retained_for_verification',
                      'source_values': {
                        'first': ['10'],
                        'second': ['20'],
                      },
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Clinical explanation'));
      await tester.pumpAndSettle();
      expect(find.text('Original clinical explanation'), findsOneWidget);
      expect(find.text('Specialist medical content'), findsOneWidget);
      expect(
        find.textContaining('Selected wording from: radvisa.com'),
        findsOneWidget,
      );
      expect(find.textContaining('snapshot-one'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Duplicates represented by retained passages (1)'),
      );
      await tester.tap(
        find.text('Duplicates represented by retained passages (1)'),
      );
      await tester.pumpAndSettle();
      expect(find.text('semantic_equivalent_v4'), findsOneWidget);
      expect(
        find.textContaining('Retained equivalent: retained-clinical'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Recorded disagreements (1)'));
      await tester.tap(find.text('Recorded disagreements (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Different thresholds'), findsOneWidget);
      expect(find.textContaining('first: 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
