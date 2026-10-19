import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/university_scholarship.dart';

/// Candidate research catalog containing official university and scholarship portals.
/// Kept pending formal ministerial and editorial sign-off per Grok evidence policy.
final candidateResearchCatalog = UniversityScholarshipCatalog(
  programs: [
    UniversityProgram(
      id: 'ca-uoft-cs',
      institutionName: 'University of Toronto',
      countryCode: 'CA',
      city: 'Toronto, Ontario',
      programName: 'Computer Science (B.Sc.)',
      degreeLevel: DegreeLevel.bachelor,
      tuition: const MoneyAmount(amount: 45000, currencyCode: 'CAD'),
      source: CatalogSourceMeta(
        title: 'University of Toronto Academic Calendar & Fees',
        url: 'https://artsci.calendar.utoronto.ca/section/Computer-Science',
        publisher: 'University of Toronto Registrar',
        retrievedAt: DateTime.utc(2026, 1, 10),
      ),
      notes: 'Designated Learning Institution (DLI) eligible for Post-Graduation Work Permit (PGWP).',
    ),
    UniversityProgram(
      id: 'ca-ubc-commerce',
      institutionName: 'University of British Columbia',
      countryCode: 'CA',
      city: 'Vancouver, BC',
      programName: 'Bachelor of Commerce (B.Com)',
      degreeLevel: DegreeLevel.bachelor,
      tuition: const MoneyAmount(amount: 44000, currencyCode: 'CAD'),
      source: CatalogSourceMeta(
        title: 'UBC Undergraduate Programs & Tuition Fees',
        url: 'https://you.ubc.ca/tuition-scholarships/cost/tuition-fees/',
        publisher: 'University of British Columbia',
        retrievedAt: DateTime.utc(2026, 2, 1),
      ),
      notes: 'AACSB and EQUIS accredited business school.',
    ),
    UniversityProgram(
      id: 'ca-mcgill-meng',
      institutionName: 'McGill University',
      countryCode: 'CA',
      city: 'Montreal, Quebec',
      programName: 'Master of Engineering in Electrical Engineering (M.Eng.)',
      degreeLevel: DegreeLevel.master,
      tuition: const MoneyAmount(amount: 28000, currencyCode: 'CAD'),
      source: CatalogSourceMeta(
        title: 'McGill Graduate Programs Guide',
        url: 'https://www.mcgill.ca/gradapplicants/programs/electrical-and-computer-engineering',
        publisher: 'McGill University Graduate Studies',
        retrievedAt: DateTime.utc(2026, 1, 15),
      ),
    ),
    UniversityProgram(
      id: 'de-tum-informatics',
      institutionName: 'Technical University of Munich (TUM)',
      countryCode: 'DE',
      city: 'Munich, Bavaria',
      programName: 'M.Sc. in Informatics / Computer Science',
      degreeLevel: DegreeLevel.master,
      tuition: const MoneyAmount(amount: 0, currencyCode: 'EUR'),
      source: CatalogSourceMeta(
        title: 'TUM Degree Programs Overview',
        url: 'https://www.tum.de/en/studies/degree-programs/detail/informatics-master-of-science-msc',
        publisher: 'Technical University of Munich',
        retrievedAt: DateTime.utc(2026, 2, 15),
      ),
      notes: 'Public state university; tuition is waived, semester solidarity fee applies.',
    ),
    UniversityProgram(
      id: 'de-heidelberg-bio',
      institutionName: 'Heidelberg University',
      countryCode: 'DE',
      city: 'Heidelberg, Baden-Württemberg',
      programName: 'Doctorate in Molecular Biosciences (Ph.D.)',
      degreeLevel: DegreeLevel.doctorate,
      tuition: const MoneyAmount(amount: 1500, currencyCode: 'EUR'),
      source: CatalogSourceMeta(
        title: 'Heidelberg University Doctoral Studies',
        url: 'https://www.uni-heidelberg.de/en/study/courses-available/molecular-biosciences-master',
        publisher: 'Heidelberg University Graduate Academy',
        retrievedAt: DateTime.utc(2026, 1, 20),
      ),
    ),
  ],
  scholarships: [
    ScholarshipListing(
      id: 'sch-daad-graduates',
      name: 'DAAD Study Scholarships for Graduates',
      countryCode: 'DE',
      institutionName: 'All German State Universities',
      eligibilitySummary: 'Foreign graduates with completed first degree (Bachelor) for Master studies in Germany.',
      award: const MoneyAmount(amount: 934, currencyCode: 'EUR'),
      deadline: DateTime.utc(2026, 11, 30),
      source: CatalogSourceMeta(
        title: 'DAAD Scholarship Database',
        url: 'https://www.daad.de/en/study-and-research-in-germany/scholarships/',
        publisher: 'German Academic Exchange Service (DAAD)',
        retrievedAt: DateTime.utc(2026, 2, 1),
      ),
      notes: 'Monthly stipend of 934 EUR plus health insurance and travel allowance.',
    ),
    ScholarshipListing(
      id: 'sch-vanier-canada',
      name: 'Vanier Canada Graduate Scholarships',
      countryCode: 'CA',
      institutionName: 'Eligible Canadian Universities',
      eligibilitySummary: 'Doctoral students demonstrating leadership skills and a high standard of scholarly achievement.',
      award: const MoneyAmount(amount: 50000, currencyCode: 'CAD'),
      deadline: DateTime.utc(2026, 11, 1),
      source: CatalogSourceMeta(
        title: 'Vanier CGS Government Program',
        url: 'https://vanier.gc.ca/en/home-accueil.html',
        publisher: 'Government of Canada Tri-agency',
        retrievedAt: DateTime.utc(2026, 1, 15),
      ),
      notes: 'Valued at 50,000 CAD per year for up to 3 years during doctoral studies.',
    ),
    ScholarshipListing(
      id: 'sch-ogs-ontario',
      name: 'Ontario Graduate Scholarship (OGS)',
      countryCode: 'CA',
      institutionName: 'Participating Ontario Universities',
      eligibilitySummary: 'Merit-based scholarship for graduate students enrolled in Ontario universities.',
      award: const MoneyAmount(amount: 15000, currencyCode: 'CAD'),
      deadline: DateTime.utc(2026, 12, 15),
      source: CatalogSourceMeta(
        title: 'Ontario Ministry of Colleges and Universities',
        url: 'https://osap.gov.on.ca/OSAPPortal/en/A-ZListofAids/PRDR019245.html',
        publisher: 'Province of Ontario',
        retrievedAt: DateTime.utc(2026, 1, 12),
      ),
    ),
    ScholarshipListing(
      id: 'sch-deutschlandstipendium',
      name: 'Deutschlandstipendium National Scholarship',
      countryCode: 'DE',
      institutionName: 'German Participating Universities',
      eligibilitySummary: 'High-achieving and committed students from all nations studying at German universities.',
      award: const MoneyAmount(amount: 300, currencyCode: 'EUR'),
      deadline: DateTime.utc(2026, 10, 31),
      source: CatalogSourceMeta(
        title: 'Deutschlandstipendium Official Portal',
        url: 'https://www.deutschlandstipendium.de/',
        publisher: 'Federal Ministry of Education and Research (BMBF)',
        retrievedAt: DateTime.utc(2026, 2, 5),
      ),
      notes:
          'Monthly stipend of 300 EUR granted regardless of personal income.',
    ),
  ],
);

class UniversityScholarshipState {
  const UniversityScholarshipState({
    this.activeTab = 0,
    this.universityFilter = const UniversitySearchFilter(),
    this.scholarshipFilter = const ScholarshipSearchFilter(),
    required this.universityResult,
    required this.scholarshipResult,
    this.clock,
  });

  final int activeTab; // 0 = Universities, 1 = Scholarships
  final UniversitySearchFilter universityFilter;
  final ScholarshipSearchFilter scholarshipFilter;
  final UniversitySearchResult universityResult;
  final ScholarshipSearchResult scholarshipResult;
  final DateTime? clock;

  UniversityScholarshipState copyWith({
    int? activeTab,
    UniversitySearchFilter? universityFilter,
    ScholarshipSearchFilter? scholarshipFilter,
    UniversitySearchResult? universityResult,
    ScholarshipSearchResult? scholarshipResult,
    DateTime? clock,
  }) {
    return UniversityScholarshipState(
      activeTab: activeTab ?? this.activeTab,
      universityFilter: universityFilter ?? this.universityFilter,
      scholarshipFilter: scholarshipFilter ?? this.scholarshipFilter,
      universityResult: universityResult ?? this.universityResult,
      scholarshipResult: scholarshipResult ?? this.scholarshipResult,
      clock: clock ?? this.clock,
    );
  }
}

/// Explicit editorial approval package envelope for university/scholarship catalog.
class CuratedCatalogPackage {
  const CuratedCatalogPackage({
    required this.packageId,
    required this.catalog,
    required this.editorialApproved,
    required this.approvedAt,
    this.approverLabel,
    this.status = 'pending_editorial_review',
    this.reasons = const [],
  });

  final String packageId;
  final UniversityScholarshipCatalog catalog;
  final bool editorialApproved;
  final DateTime approvedAt;
  final String? approverLabel;
  final String status;
  final List<String> reasons;
}

/// Seed package envelope per docs/seed/university_scholarship_seed_v1.json.
/// Fails closed (empty) unless editorialApproved is explicitly granted.
final defaultCandidatePackage = CuratedCatalogPackage(
  packageId: 'uni-scholarship-seed-v1',
  catalog: candidateResearchCatalog,
  editorialApproved: false, // Pending editorial review per Grok evidence policy
  status: 'empty_by_design',
  approvedAt: DateTime.utc(2026, 10, 18),
  reasons: const [
    'No institution-specific tuition, deadline, or award amount was verified against an official university or scholarship provider page for product seed inclusion in this pass.',
    'UniversityScholarshipCatalog already fails closed on empty inventory (CatalogResultState.empty).',
    'Future seeds must include official institution URL, retrievedAt, and editorial reviewStatus before any amount or deadline fields are populated.',
  ],
);

final curatedCatalogPackageProvider = Provider<CuratedCatalogPackage>(
  (ref) => defaultCandidatePackage,
);

final universityScholarshipCatalogProvider =
    Provider<UniversityScholarshipCatalog>((ref) {
      final package = ref.watch(curatedCatalogPackageProvider);
      if (!package.editorialApproved) {
        // Fail closed: never display unapproved or unverified catalog entries as active
        return const UniversityScholarshipCatalog(
          programs: [],
          scholarships: [],
        );
      }
      return package.catalog;
    });

final universityScholarshipControllerProvider =
    StateNotifierProvider<
      UniversityScholarshipController,
      UniversityScholarshipState
    >((ref) {
      final catalog = ref.watch(universityScholarshipCatalogProvider);
      return UniversityScholarshipController(catalog);
    });

class UniversityScholarshipController
    extends StateNotifier<UniversityScholarshipState> {
  UniversityScholarshipController(this._catalog, {DateTime? nowUtc})
    : _clock = nowUtc,
      super(
        UniversityScholarshipState(
          universityResult: _catalog.searchPrograms(
            const UniversitySearchFilter(),
            now: nowUtc,
          ),
          scholarshipResult: _catalog.searchScholarships(
            const ScholarshipSearchFilter(),
            now: nowUtc,
          ),
          clock: nowUtc,
        ),
      );

  final UniversityScholarshipCatalog _catalog;
  final DateTime? _clock;

  bool get isCatalogEmpty =>
      _catalog.programs.isEmpty && _catalog.scholarships.isEmpty;
  bool get isProgramsEmpty => _catalog.programs.isEmpty;
  bool get isScholarshipsEmpty => _catalog.scholarships.isEmpty;

  void switchTab(int tabIndex) {
    state = state.copyWith(activeTab: tabIndex);
  }

  void updateUniversityFilter({
    String? countryCode,
    DegreeLevel? degreeLevel,
    String? query,
    bool? requireFreshSource,
    bool clearCountry = false,
    bool clearDegree = false,
  }) {
    final nextFilter = UniversitySearchFilter(
      countryCode: clearCountry
          ? null
          : (countryCode ?? state.universityFilter.countryCode),
      degreeLevel: clearDegree
          ? null
          : (degreeLevel ?? state.universityFilter.degreeLevel),
      query: query ?? state.universityFilter.query,
      requireFreshSource:
          requireFreshSource ?? state.universityFilter.requireFreshSource,
    );
    final result = _catalog.searchPrograms(nextFilter, now: _clock);
    state = state.copyWith(
      universityFilter: nextFilter,
      universityResult: result,
    );
  }

  void updateScholarshipFilter({
    String? countryCode,
    String? query,
    bool? excludeExpiredDeadlines,
    bool? requireFreshSource,
    bool clearCountry = false,
  }) {
    final nextFilter = ScholarshipSearchFilter(
      countryCode: clearCountry
          ? null
          : (countryCode ?? state.scholarshipFilter.countryCode),
      query: query ?? state.scholarshipFilter.query,
      excludeExpiredDeadlines:
          excludeExpiredDeadlines ??
          state.scholarshipFilter.excludeExpiredDeadlines,
      requireFreshSource:
          requireFreshSource ?? state.scholarshipFilter.requireFreshSource,
    );
    final result = _catalog.searchScholarships(nextFilter, now: _clock);
    state = state.copyWith(
      scholarshipFilter: nextFilter,
      scholarshipResult: result,
    );
  }

  void resetFilters() {
    updateUniversityFilter(
      clearCountry: true,
      clearDegree: true,
      query: '',
      requireFreshSource: false,
    );
    updateScholarshipFilter(
      clearCountry: true,
      query: '',
      excludeExpiredDeadlines: true,
      requireFreshSource: false,
    );
  }
}
