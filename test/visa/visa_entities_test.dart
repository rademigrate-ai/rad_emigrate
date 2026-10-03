import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';

void main() {
  test('catalog keeps provenance with every programme', () {
    final programme = VisaProgram(
      id: 'programme',
      slug: 'study-canada',
      title: 'Study in Canada',
      countryId: 'canada',
      categoryId: 'study',
      summary: 'Source-backed summary',
      source: VisaSource(
        title: 'RAD source',
        url: 'https://radvisa.com/example',
        publisher: 'RAD International Institute',
        retrievedAt: DateTime.utc(2026, 10, 3),
      ),
    );

    expect(programme.source.url, startsWith('https://'));
    expect(programme.requirements, isEmpty);
  });
}
