import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';
import 'package:rad_emigrate/features/visa/domain/visa_catalog_integrity.dart';

void main() {
  const integrity = VisaCatalogIntegrity();

  VisaSource source({
    String url =
        'https://www.canada.ca/en/immigration-refugees-citizenship.html',
    String publisher = 'IRCC',
  }) {
    return VisaSource(
      title: 'Official program page',
      url: url,
      publisher: publisher,
      retrievedAt: DateTime.utc(2026, 1, 1),
    );
  }

  test('empty program is not safe guidance', () {
    final report = integrity.evaluateProgram(
      VisaProgram(
        id: 'p1',
        slug: 'p1',
        title: '',
        countryId: '',
        categoryId: 'c1',
        summary: '',
        source: source(url: '', publisher: ''),
      ),
    );
    expect(report.safeForGuidance, isFalse);
    expect(
      report.completeness,
      isIn([
        VisaDataCompleteness.empty,
        VisaDataCompleteness.unverified,
        VisaDataCompleteness.partial,
      ]),
    );
  });

  test('fees without source are unverified', () {
    final report = integrity.evaluateProgram(
      VisaProgram(
        id: 'p1',
        slug: 'p1',
        title: 'Study permit',
        countryId: 'ca',
        categoryId: 'study',
        summary: 'Overview',
        fees: 'CAD 150',
        source: source(url: 'http://insecure.example', publisher: ''),
      ),
    );
    expect(report.completeness, VisaDataCompleteness.unverified);
    expect(report.issues, contains('fees_unverified'));
    expect(report.safeForGuidance, isFalse);
  });

  test('contradictory mandatory empty requirement', () {
    final report = integrity.evaluateProgram(
      VisaProgram(
        id: 'p1',
        slug: 'p1',
        title: 'Study permit',
        countryId: 'ca',
        categoryId: 'study',
        summary: 'Overview',
        requirements: const [
          VisaRequirement(text: '', displayOrder: 1, isMandatory: true),
        ],
        source: source(),
      ),
    );
    expect(report.completeness, VisaDataCompleteness.contradictory);
    expect(report.safeForGuidance, isFalse);
  });

  test('sourced program with requirements and steps can be complete', () {
    final report = integrity.evaluateProgram(
      VisaProgram(
        id: 'p1',
        slug: 'p1',
        title: 'Study permit',
        countryId: 'ca',
        categoryId: 'study',
        summary: 'Overview from official source',
        requirements: const [
          VisaRequirement(text: 'Letter of acceptance', displayOrder: 1),
        ],
        steps: const [
          VisaStep(
            title: 'Apply online',
            description: 'Use official portal',
            displayOrder: 1,
          ),
        ],
        source: source(),
      ),
    );
    expect(report.completeness, VisaDataCompleteness.complete);
    expect(report.safeForGuidance, isTrue);
  });

  test('country summary alone is not program guidance', () {
    final report = integrity.evaluateCountry(
      const Country(
        id: 'ca',
        name: 'Canada',
        code: 'CA',
        flagEmoji: '🇨🇦',
        slug: 'canada',
        summary: 'Popular destination',
      ),
    );
    expect(report.completeness, VisaDataCompleteness.complete);
    expect(report.safeForGuidance, isFalse);
  });
}
