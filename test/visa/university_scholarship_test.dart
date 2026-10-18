import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/domain/entities/university_scholarship.dart';

void main() {
  final now = DateTime.utc(2026, 10, 18);

  final freshSource = CatalogSourceMeta(
    title: 'University registry',
    url: 'https://example.edu/registry',
    retrievedAt: now.subtract(const Duration(days: 10)),
    publisher: 'Example EDU',
  );

  final staleSource = CatalogSourceMeta(
    title: 'Old listing',
    url: 'https://example.edu/old',
    retrievedAt: now.subtract(const Duration(days: 400)),
  );

  final programs = [
    UniversityProgram(
      id: 'u1',
      institutionName: 'University of Toronto',
      countryCode: 'CA',
      programName: 'Computer Science',
      degreeLevel: DegreeLevel.bachelor,
      tuition: const MoneyAmount(amount: 45000, currencyCode: 'CAD'),
      source: freshSource,
    ),
    UniversityProgram(
      id: 'u2',
      institutionName: 'TU Berlin',
      countryCode: 'DE',
      programName: 'Mechanical Engineering',
      degreeLevel: DegreeLevel.master,
      source: staleSource,
    ),
    const UniversityProgram(
      id: 'u3',
      institutionName: 'Unknown College',
      countryCode: 'CA',
      programName: 'Arts',
      degreeLevel: DegreeLevel.bachelor,
    ),
  ];

  final scholarships = [
    ScholarshipListing(
      id: 's1',
      name: 'Merit Award',
      countryCode: 'CA',
      institutionName: 'University of Toronto',
      award: const MoneyAmount(amount: 5000, currencyCode: 'CAD'),
      deadline: now.add(const Duration(days: 30)),
      source: freshSource,
    ),
    ScholarshipListing(
      id: 's2',
      name: 'Expired Grant',
      countryCode: 'CA',
      deadline: now.subtract(const Duration(days: 5)),
      source: freshSource,
    ),
  ];

  final catalog = UniversityScholarshipCatalog(
    programs: programs,
    scholarships: scholarships,
  );

  group('UniversityScholarshipCatalog programs', () {
    test('empty catalog returns empty state', () {
      const empty = UniversityScholarshipCatalog();
      final r = empty.searchPrograms(const UniversitySearchFilter());
      expect(r.state, CatalogResultState.empty);
      expect(r.items, isEmpty);
    });

    test('filter by country and degree', () {
      final r = catalog.searchPrograms(
        const UniversitySearchFilter(
          countryCode: 'CA',
          degreeLevel: DegreeLevel.bachelor,
        ),
        now: now,
      );
      expect(r.items.length, 2);
      expect(r.items.every((p) => p.countryCode == 'CA'), isTrue);
    });

    test('query matches institution name', () {
      final r = catalog.searchPrograms(
        const UniversitySearchFilter(query: 'toronto'),
        now: now,
      );
      expect(r.items.length, 1);
      expect(r.items.first.id, 'u1');
    });

    test('requireFreshSource excludes stale and missing', () {
      final r = catalog.searchPrograms(
        const UniversitySearchFilter(requireFreshSource: true),
        now: now,
      );
      expect(r.items.map((e) => e.id), ['u1']);
    });

    test('missing source yields unknownSource state when present', () {
      final r = catalog.searchPrograms(
        const UniversitySearchFilter(countryCode: 'CA'),
        now: now,
      );
      expect(r.state, CatalogResultState.unknownSource);
    });
  });

  group('UniversityScholarshipCatalog scholarships', () {
    test('excludes expired deadlines by default', () {
      final r = catalog.searchScholarships(
        const ScholarshipSearchFilter(countryCode: 'CA'),
        now: now,
      );
      expect(r.items.map((e) => e.id), ['s1']);
    });

    test('can include expired when flag false', () {
      final r = catalog.searchScholarships(
        const ScholarshipSearchFilter(
          countryCode: 'CA',
          excludeExpiredDeadlines: false,
        ),
        now: now,
      );
      expect(r.items.length, 2);
    });

    test('empty scholarships catalog', () {
      const empty = UniversityScholarshipCatalog();
      final r = empty.searchScholarships(const ScholarshipSearchFilter());
      expect(r.state, CatalogResultState.empty);
    });
  });

  group('EvidenceFreshness', () {
    test('fresh / aging / stale classification', () {
      expect(freshSource.freshness(now), EvidenceFreshness.fresh);
      expect(staleSource.freshness(now), EvidenceFreshness.stale);
      final aging = CatalogSourceMeta(
        title: 't',
        url: 'u',
        retrievedAt: now.subtract(const Duration(days: 200)),
      );
      expect(aging.freshness(now), EvidenceFreshness.aging);
    });
  });
}
