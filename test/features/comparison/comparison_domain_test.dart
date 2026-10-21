// Unit tests for the Country & Pathway Comparison domain.
//
// The core truthfulness contract: a cell is only ever `published` when it
// carries real sourced content, and anything the catalog omits becomes an
// explicit `missing` so the UI shows a "not published" indicator rather than
// inventing an eligibility, cost, or timeline value.

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/comparison/domain/entities/pathway_comparison.dart';

VisaProgramLike _program({
  String? processingTime,
  String? fees,
  List<String> requirements = const [],
}) {
  return VisaProgramLike(
    id: 'p1',
    countryName: 'Canada',
    flagEmoji: '🇨🇦',
    title: 'Study permit',
    categoryName: 'Study',
    processingTime: processingTime,
    fees: fees,
    requirements: requirements,
    sourceTitle: 'Study permit',
    sourcePublisher: 'Canada.ca',
    sourceUrl: 'https://canada.ca',
    sourceRetrievedAt: DateTime.utc(2026, 1, 15),
  );
}

void main() {
  group('entriesFromPrograms', () {
    test('maps published attributes to prose/list cells', () {
      final entries = entriesFromPrograms([
        _program(
          processingTime: '8 weeks',
          fees: 'CAD 150',
          requirements: ['Valid passport', 'Letter of acceptance'],
        ),
      ]);
      expect(entries, hasLength(1));
      final entry = entries.first;
      expect(entry.processingTime.status, CellStatus.prose);
      expect(entry.processingTime.text, '8 weeks');
      expect(entry.fees.status, CellStatus.prose);
      expect(entry.fees.text, 'CAD 150');
      expect(entry.requirements.status, CellStatus.published);
      expect(entry.requirements.items, hasLength(2));
    });

    test('omitted attributes become explicit missing cells', () {
      final entries = entriesFromPrograms([_program()]);
      final entry = entries.first;
      expect(entry.processingTime.isMissing, isTrue);
      expect(entry.fees.isMissing, isTrue);
      expect(entry.requirements.isMissing, isTrue);
    });

    test(
      'blank strings are treated as missing, not empty published values',
      () {
        final entries = entriesFromPrograms([
          _program(processingTime: '   ', fees: '', requirements: ['', '  ']),
        ]);
        final entry = entries.first;
        expect(entry.processingTime.isMissing, isTrue);
        expect(entry.fees.isMissing, isTrue);
        expect(entry.requirements.isMissing, isTrue);
      },
    );
  });

  group('ComparisonEntry.cellFor', () {
    test('returns published identity attributes for the constant fields', () {
      final entry = entriesFromPrograms([_program()]).first;
      expect(entry.cellFor(ComparisonField.country).text, 'Canada');
      expect(entry.cellFor(ComparisonField.pathway).text, 'Study permit');
      expect(entry.cellFor(ComparisonField.category).text, 'Study');
      expect(entry.cellFor(ComparisonField.country).isPublished, isTrue);
    });

    test('returns the stored cell for data-driven fields', () {
      final entry = entriesFromPrograms([_program(fees: 'CAD 150')]).first;
      expect(entry.cellFor(ComparisonField.fees).text, 'CAD 150');
      expect(entry.cellFor(ComparisonField.processingTime).isMissing, isTrue);
    });
  });

  group('ComparisonCell invariants', () {
    test('a published text cell carries its value', () {
      const cell = ComparisonCell.publishedText('x');
      expect(cell.isPublished, isTrue);
      expect(cell.isMissing, isFalse);
      expect(cell.text, 'x');
    });

    test('a missing cell carries no value', () {
      const cell = ComparisonCell.missing();
      expect(cell.isMissing, isTrue);
      expect(cell.text, isNull);
      expect(cell.items, isNull);
    });
  });
}
