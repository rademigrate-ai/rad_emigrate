import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/domain/entities/search_entities.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/safe_highlighted_text.dart';

void main() {
  group('SafeHighlightedText Widget Tests', () {
    testWidgets('renders plain text when matchRanges is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeHighlightedText(
              text: 'ویزای تحصیلی آلمان',
              matchRanges: [],
            ),
          ),
        ),
      );

      expect(find.text('ویزای تحصیلی آلمان'), findsOneWidget);
    });

    testWidgets('renders highlighted TextSpans safely without HTML tags', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeHighlightedText(
              text: 'کارت فرصت آلمان',
              matchRanges: [
                MatchRange(start: 5, end: 9), // "فرصت"
              ],
            ),
          ),
        ),
      );

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsOneWidget);

      final richText = tester.widget<RichText>(richTextFinder);
      expect(richText.text.toPlainText(), 'کارت فرصت آلمان');

      final rootSpan = richText.text as TextSpan;
      final effectiveSpans =
          (rootSpan.children != null &&
              rootSpan.children!.length == 1 &&
              (rootSpan.children![0] as TextSpan).children != null)
          ? (rootSpan.children![0] as TextSpan).children!
          : (rootSpan.children ?? []);

      expect(effectiveSpans.length, 3);
      expect((effectiveSpans[0] as TextSpan).text, 'کارت ');
      expect((effectiveSpans[1] as TextSpan).text, 'فرصت');
      expect((effectiveSpans[2] as TextSpan).text, ' آلمان');
    });

    testWidgets('handles out of bounds ranges gracefully without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeHighlightedText(
              text: 'کوتاه',
              matchRanges: [MatchRange(start: 0, end: 100)],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(RichText), findsOneWidget);
    });
  });
}
