import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/domain/structured_review.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/structured_review_viewer.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/editorial_rich_block.dart';

void main() {
  final table = <String, dynamic>{
    'id': 'table',
    'original_structure': {
      'type': 'table',
      'caption': 'Synthetic',
      'rows': [
        [
          {'text': 'Before', 'header': true, 'colspan': 2, 'rowspan': 1},
        ],
      ],
    },
    'provenance': [
      {'source_id': 'source', 'start': 0, 'end': 6},
    ],
  };
  final patch = <String, dynamic>{
    'id': 'patch',
    'block_id': 'table',
    'operation': 'replace_text',
    'path': ['rows', '0', '0', 'text'],
    'text': 'After',
    'evidence': {
      'excerpt': 'Synthetic evidence',
      'locator': 'Test',
      'snapshot_id': 'snapshot',
    },
  };
  test(
    'cell preview retains source structure, attribution and span geometry',
    () {
      final hash = jsonEncode(table);
      final preview = previewRichBlock(table, patch, editedText: 'Manual');
      expect(jsonEncode(table), hash);
      expect(preview['original_structure'], table['original_structure']);
      expect(preview['provenance'], table['provenance']);
      expect(preview['current_structure']['rows'][0][0], {
        'text': 'Manual',
        'header': true,
        'colspan': 2,
        'rowspan': 1,
      });
    },
  );
  testWidgets('reader renders edited structure, not obsolete source wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorialRichBlock(block: previewRichBlock(table, patch)),
        ),
      ),
    );
    expect(find.text('After'), findsOneWidget);
    expect(find.text('Before'), findsNothing);
  });
  for (final width in [390.0, 768.0, 1440.0]) {
    for (final rtl in [false, true]) {
      testWidgets('full rich review ${width.toInt()} ${rtl ? 'RTL' : 'LTR'}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: StructuredReviewViewer(
                    sections: [
                      {
                        'heading': 'Whole page',
                        'blocks': [
                          table,
                          {
                            'id': 'untouched',
                            'original_structure': {
                              'type': 'paragraph',
                              'text': 'UNIQUE unchanged context فارسی',
                            },
                          },
                        ],
                      },
                    ],
                    patches: [patch],
                    decisions: const {},
                    edits: const {},
                    onAction: (id, action) => calls.add('$id:$action'),
                    onEdit: (_, _) {},
                    isPersian: rtl,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Before'), findsOneWidget);
        expect(find.text('After'), findsOneWidget);
        expect(find.text('UNIQUE unchanged context فارسی'), findsOneWidget);
        await tester.tap(find.text(rtl ? 'رد' : 'Reject'));
        expect(calls, ['patch:reject']);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('edit modal supports large leaf content up to 40000 chars', (
    tester,
  ) async {
    String? editedResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StructuredReviewViewer(
            sections: [
              {
                'heading': 'Test Section',
                'blocks': [table],
              },
            ],
            patches: [patch],
            decisions: const {},
            edits: const {},
            onAction: (_, _) {},
            onEdit: (_, text) => editedResult = text,
            isPersian: false,
          ),
        ),
      ),
    );

    // Tap "Edit" to open modal
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    final widget = tester.widget<TextField>(textField);
    expect(widget.maxLength, 40000);

    // Enter large text exceeding 20,000 chars
    final largeText = 'A' * 25000;
    await tester.enterText(textField, largeText);
    await tester.pump();

    await tester.tap(find.text('Use edit'));
    await tester.pumpAndSettle();

    expect(editedResult, largeText);
    expect(tester.takeException(), isNull);
  });
}
