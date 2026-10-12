import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';

/// Deterministic visa catalog for journey tests — no network.
VisaCatalog buildFixtureCatalog() {
  final src = VisaSource(
    title: 'Official pathway note',
    url: 'https://example.test/source',
    publisher: 'RAD Test Fixture',
    retrievedAt: DateTime.utc(2026, 1, 15),
  );
  final countries = [
    const Country(
      id: 'ca',
      name: 'Canada',
      code: 'CA',
      flagEmoji: '🇨🇦',
      slug: 'canada',
    ),
    const Country(
      id: 'de',
      name: 'Germany',
      code: 'DE',
      flagEmoji: '🇩🇪',
      slug: 'germany',
    ),
  ];
  final categories = [
    const VisaCategory(
      id: 'study',
      name: 'Study',
      description: 'Study pathways',
      slug: 'study',
    ),
    const VisaCategory(
      id: 'work',
      name: 'Work',
      description: 'Work pathways',
      slug: 'work',
    ),
  ];
  final programs = [
    VisaProgram(
      id: 'ca-study',
      slug: 'canada-study',
      title: 'Canada Study Permit',
      countryId: 'ca',
      categoryId: 'study',
      summary: 'Study in Canada with a study permit.',
      description: 'Full structured pathway for testing.',
      requirements: const [
        VisaRequirement(
          text: 'Letter of acceptance',
          displayOrder: 1,
          isMandatory: true,
        ),
        VisaRequirement(
          text: 'Proof of funds',
          displayOrder: 2,
          isMandatory: true,
        ),
      ],
      steps: const [
        VisaStep(
          title: 'Gather documents',
          description: 'Collect required files',
          displayOrder: 1,
        ),
        VisaStep(
          title: 'Submit application',
          description: 'Apply online',
          displayOrder: 2,
        ),
      ],
      processingTime: '4–12 weeks',
      fees: 'CAD 150',
      source: src,
    ),
    VisaProgram(
      id: 'de-work',
      slug: 'germany-work',
      title: 'Germany Work Visa',
      countryId: 'de',
      categoryId: 'work',
      summary: 'Employment pathway summary.',
      source: src,
    ),
  ];
  return VisaCatalog(
    countries: countries,
    categories: categories,
    programs: programs,
  );
}

/// Same filter predicates as VisaPage._catalog (keep in sync with product UI).
List<VisaProgram> filterPrograms({
  required VisaCatalog catalog,
  String? countryId,
  String? categoryId,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  return catalog.programs
      .where(
        (program) =>
            (countryId == null || program.countryId == countryId) &&
            (categoryId == null || program.categoryId == categoryId) &&
            (q.isEmpty ||
                program.title.toLowerCase().contains(q) ||
                program.summary.toLowerCase().contains(q)),
      )
      .toList();
}
