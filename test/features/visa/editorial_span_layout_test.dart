import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/editorial_rich_block.dart';

void main() {
  final captured = (jsonDecode(
    File('test/fixtures/editorial/source_span_tables.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  for (final direction in TextDirection.values) {
    testWidgets(
      'actual UCAT source retains audience and fee columns under rowspans in $direction',
      (tester) async {
        final table =
            captured.firstWhere(
                  (fixture) => fixture['has_rowspan'] == true,
                )['table']
                as Map<String, dynamic>;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Directionality(
                textDirection: direction,
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: 320,
                    child: EditorialRichBlock(block: table),
                  ),
                ),
              ),
            ),
          ),
        );
        final inside = tester.getRect(find.text('داوطلبان داخل بریتانیا'));
        final outside = tester.getRect(find.text('داوطلبان خارج از بریتانیا'));
        final country = tester.getRect(find.text('UCAT بریتانیا'));
        final feeInside = tester.getRect(find.text('70 پوند'));
        final feeOutside = tester.getRect(find.text('115 پوند'));
        expect(outside.left, closeTo(inside.left, 0.1));
        expect(feeOutside.left, closeTo(feeInside.left, 0.1));
        expect(outside.top, greaterThan(inside.top));
        expect(country.height, greaterThan(inside.height));
        if (direction == TextDirection.ltr) {
          expect(outside.left, greaterThan(country.right));
          expect(feeOutside.left, greaterThan(outside.right));
        } else {
          expect(outside.right, lessThan(country.left));
          expect(feeOutside.right, lessThan(outside.left));
        }
        final firstAnz = tester.getRect(
          find.text('آزمون در استرالیا یا نیوزیلند'),
        );
        for (final audience in [
          'آزمون خارج از استرالیا و نیوزیلند',
          'داوطلبان دارای تخفیف (استرالیا فقط)',
        ]) {
          expect(
            tester.getRect(find.text(audience)).left,
            closeTo(firstAnz.left, 0.1),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'captured colspan cells occupy the full source grid width at narrow width',
    (tester) async {
      final fixture = captured.firstWhere(
        (fixture) => fixture['has_colspan'] == true,
      );
      final table = fixture['table'] as Map<String, dynamic>;
      final rows = table['rows'] as List;
      final cells = rows
          .expand((row) => row as List)
          .cast<Map<String, dynamic>>()
          .toList();
      final wide = cells.firstWhere(
        (cell) => int.parse('${cell['colspan']}') > 1,
      );
      final ordinary = cells.firstWhere(
        (cell) =>
            int.parse('${cell['colspan']}') == 1 &&
            '${cell['text']}'.isNotEmpty,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: EditorialRichBlock(block: table),
              ),
            ),
          ),
        ),
      );
      final wideRect = tester.getRect(find.text(wide['text'] as String).first);
      final ordinaryRect = tester.getRect(
        find.text(ordinary['text'] as String).first,
      );
      expect(wideRect.width, greaterThan(ordinaryRect.width * 2));
      for (final cell in cells) {
        if ('${cell['text']}'.isNotEmpty) {
          expect(find.text(cell['text'] as String), findsWidgets);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('span coordinates are exposed to assistive readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final table =
          captured.firstWhere(
                (fixture) => fixture['has_rowspan'] == true,
              )['table']
              as Map<String, dynamic>;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EditorialRichBlock(block: table)),
        ),
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'Row 2, column 1, spans 2 rows and 1 columns'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'Row 3, column 2, spans 1 rows and 1 columns'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
