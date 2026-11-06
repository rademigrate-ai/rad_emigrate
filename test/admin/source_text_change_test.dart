import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/domain/source_text_change.dart';

void main() {
  String side(List<TextChangeRun> runs, bool before) => runs
      .where(
        (r) =>
            r.kind !=
            (before ? TextChangeKind.inserted : TextChangeKind.removed),
      )
      .map((r) => r.text)
      .join();

  test(
    'fee and deadline edits preserve intervening evidence and exact whitespace',
    () {
      const before = 'Fee 100.\nDeadline June 1; evidence unchanged.';
      const after = 'Fee 120.\nDeadline July 1; evidence unchanged.';
      final runs = sourceTextChanges(before, after);
      expect(side(runs, true), before);
      expect(side(runs, false), after);
      expect(
        runs.where((r) => r.kind == TextChangeKind.removed).map((r) => r.text),
        ['100.', 'June'],
      );
      expect(
        runs.where((r) => r.kind == TextChangeKind.inserted).map((r) => r.text),
        ['120.', 'July'],
      );
    },
  );

  test('Persian, combining marks, emoji and literal HTML remain verbatim', () {
    for (final (before, after) in [
      ('مهلت ۱ خرداد\nمبلغ ۱۰۰', 'مهلت ۲ خرداد\nمبلغ ۱۲۰'),
      ('Cafe\u0301 👨‍👩‍👧 <b>old</b>', 'Cafe\u0301 👨‍👩‍👧 <b>new</b>'),
      ('', 'Added text'),
      ('Removed text', ''),
      ('Same\n  text', 'Same\n  text'),
    ]) {
      final runs = sourceTextChanges(before, after);
      expect(side(runs, true), before);
      expect(side(runs, false), after);
    }
  });

  test(
    'bounded large comparison keeps complete text and common outer context',
    () {
      final before = 'Start ${'old ' * 3000}End';
      final after = 'Start ${'new ' * 3000}End';
      final runs = sourceTextChanges(before, after);
      expect(side(runs, true), before);
      expect(side(runs, false), after);
      expect(runs.first.kind, TextChangeKind.unchanged);
      expect(runs.last.kind, TextChangeKind.unchanged);
    },
  );
}
