import 'package:flutter_test/flutter_test.dart';

import 'journey_fixtures.dart';

/// Journey 3–4: Visa destination browsing + program detail data shape.
void main() {
  final catalog = buildFixtureCatalog();

  test('UJ03 fixture catalog exposes destinations and programmes', () {
    expect(catalog.countries.length, 2);
    expect(catalog.categories.length, 2);
    expect(catalog.programs.length, 2);
    expect(catalog.countries.map((c) => c.code), containsAll(['CA', 'DE']));
  });

  test('UJ03b filter by Canada keeps only Canada Study Permit', () {
    final filtered = filterPrograms(catalog: catalog, countryId: 'ca');
    expect(filtered, hasLength(1));
    expect(filtered.single.title, 'Canada Study Permit');
  });

  test('UJ03c filter by work category keeps Germany Work Visa', () {
    final filtered = filterPrograms(catalog: catalog, categoryId: 'work');
    expect(filtered, hasLength(1));
    expect(filtered.single.id, 'de-work');
  });

  test('UJ03d search query narrows by title substring', () {
    final filtered = filterPrograms(catalog: catalog, query: 'study');
    expect(filtered, hasLength(1));
    expect(filtered.single.slug, 'canada-study');
  });

  test(
    'UJ03e empty filter combination yields empty list (empty state path)',
    () {
      final filtered = filterPrograms(
        catalog: catalog,
        countryId: 'ca',
        categoryId: 'work',
      );
      expect(
        filtered,
        isEmpty,
        reason: 'UI must show EmptyState when no programme matches',
      );
    },
  );

  test('UJ04 structured program exposes requirements and steps for detail', () {
    final program = catalog.programs.firstWhere((p) => p.id == 'ca-study');
    expect(program.requirements, isNotEmpty);
    expect(program.steps, isNotEmpty);
    expect(program.processingTime, isNotNull);
    expect(program.fees, isNotNull);
    expect(program.source.url, startsWith('https://'));
  });

  test('UJ04b pending program has empty structure for pending UI', () {
    final program = catalog.programs.firstWhere((p) => p.id == 'de-work');
    expect(program.requirements, isEmpty);
    expect(program.steps, isEmpty);
  });
}
