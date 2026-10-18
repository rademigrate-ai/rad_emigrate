// University and scholarship discovery domain foundation.
// Only models and filters; no fabricated listings or acceptance rates.

/// Source freshness classification for catalog rows.
enum EvidenceFreshness { fresh, aging, stale, unknown, conflicted }

extension EvidenceFreshnessX on EvidenceFreshness {
  String get key => name;

  static EvidenceFreshness fromString(String? value) {
    if (value == null || value.isEmpty) return EvidenceFreshness.unknown;
    return EvidenceFreshness.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EvidenceFreshness.unknown,
    );
  }
}

/// Provenance for a university or scholarship record.
class CatalogSourceMeta {
  const CatalogSourceMeta({
    required this.title,
    required this.url,
    required this.retrievedAt,
    this.publisher,
    this.validUntil,
  });

  final String title;
  final String url;
  final DateTime retrievedAt;
  final String? publisher;
  final DateTime? validUntil;

  EvidenceFreshness freshness(
    DateTime now, {
    Duration agingAfter = const Duration(days: 180),
    Duration staleAfter = const Duration(days: 365),
  }) {
    if (validUntil != null && validUntil!.isBefore(now)) {
      return EvidenceFreshness.stale;
    }
    final age = now.difference(retrievedAt);
    if (age > staleAfter) return EvidenceFreshness.stale;
    if (age > agingAfter) return EvidenceFreshness.aging;
    if (age.isNegative) return EvidenceFreshness.unknown;
    return EvidenceFreshness.fresh;
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'retrievedAt': retrievedAt.toIso8601String(),
    'publisher': publisher,
    'validUntil': validUntil?.toIso8601String(),
  };

  factory CatalogSourceMeta.fromJson(Map<String, dynamic> json) {
    return CatalogSourceMeta(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      retrievedAt:
          DateTime.tryParse(json['retrievedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      publisher: json['publisher'] as String?,
      validUntil: json['validUntil'] != null
          ? DateTime.tryParse(json['validUntil'] as String)
          : null,
    );
  }
}

/// Degree level filter values.
enum DegreeLevel {
  unknown,
  certificate,
  diploma,
  bachelor,
  master,
  doctorate,
  other,
}

extension DegreeLevelX on DegreeLevel {
  String get key => name;

  static DegreeLevel fromString(String? value) {
    if (value == null || value.isEmpty) return DegreeLevel.unknown;
    return DegreeLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DegreeLevel.unknown,
    );
  }
}

/// Money amount with explicit currency (no assumed FX conversion).
class MoneyAmount {
  const MoneyAmount({required this.amount, required this.currencyCode});

  final double amount;
  final String currencyCode;

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currencyCode': currencyCode,
  };

  factory MoneyAmount.fromJson(Map<String, dynamic> json) {
    return MoneyAmount(
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currencyCode'] as String? ?? 'XXX',
    );
  }
}

class UniversityProgram {
  const UniversityProgram({
    required this.id,
    required this.institutionName,
    required this.countryCode,
    required this.programName,
    required this.degreeLevel,
    this.city,
    this.tuition,
    this.source,
    this.notes,
  });

  final String id;
  final String institutionName;
  final String countryCode;
  final String? city;
  final String programName;
  final DegreeLevel degreeLevel;
  final MoneyAmount? tuition;
  final CatalogSourceMeta? source;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'institutionName': institutionName,
    'countryCode': countryCode,
    'city': city,
    'programName': programName,
    'degreeLevel': degreeLevel.name,
    'tuition': tuition?.toJson(),
    'source': source?.toJson(),
    'notes': notes,
  };

  factory UniversityProgram.fromJson(Map<String, dynamic> json) {
    return UniversityProgram(
      id: json['id'] as String? ?? '',
      institutionName: json['institutionName'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      city: json['city'] as String?,
      programName: json['programName'] as String? ?? '',
      degreeLevel: DegreeLevelX.fromString(json['degreeLevel'] as String?),
      tuition: json['tuition'] is Map
          ? MoneyAmount.fromJson(
              Map<String, dynamic>.from(json['tuition'] as Map),
            )
          : null,
      source: json['source'] is Map
          ? CatalogSourceMeta.fromJson(
              Map<String, dynamic>.from(json['source'] as Map),
            )
          : null,
      notes: json['notes'] as String?,
    );
  }
}

class ScholarshipListing {
  const ScholarshipListing({
    required this.id,
    required this.name,
    required this.countryCode,
    this.institutionName,
    this.eligibilitySummary,
    this.award,
    this.deadline,
    this.source,
    this.notes,
  });

  final String id;
  final String name;
  final String countryCode;
  final String? institutionName;
  final String? eligibilitySummary;
  final MoneyAmount? award;
  final DateTime? deadline;
  final CatalogSourceMeta? source;
  final String? notes;

  bool isDeadlinePassed(DateTime now) {
    if (deadline == null) return false;
    return deadline!.isBefore(now);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'countryCode': countryCode,
    'institutionName': institutionName,
    'eligibilitySummary': eligibilitySummary,
    'award': award?.toJson(),
    'deadline': deadline?.toIso8601String(),
    'source': source?.toJson(),
    'notes': notes,
  };

  factory ScholarshipListing.fromJson(Map<String, dynamic> json) {
    return ScholarshipListing(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      institutionName: json['institutionName'] as String?,
      eligibilitySummary: json['eligibilitySummary'] as String?,
      award: json['award'] is Map
          ? MoneyAmount.fromJson(
              Map<String, dynamic>.from(json['award'] as Map),
            )
          : null,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
      source: json['source'] is Map
          ? CatalogSourceMeta.fromJson(
              Map<String, dynamic>.from(json['source'] as Map),
            )
          : null,
      notes: json['notes'] as String?,
    );
  }
}

/// Search / filter contract for university programs.
class UniversitySearchFilter {
  const UniversitySearchFilter({
    this.countryCode,
    this.degreeLevel,
    this.query,
    this.requireFreshSource = false,
  });

  final String? countryCode;
  final DegreeLevel? degreeLevel;
  final String? query;
  final bool requireFreshSource;
}

/// Search / filter contract for scholarships.
class ScholarshipSearchFilter {
  const ScholarshipSearchFilter({
    this.countryCode,
    this.query,
    this.excludeExpiredDeadlines = true,
    this.requireFreshSource = false,
  });

  final String? countryCode;
  final String? query;
  final bool excludeExpiredDeadlines;
  final bool requireFreshSource;
}

/// Explicit result states for UI (empty / unknown / conflict / data).
enum CatalogResultState { empty, unknownSource, expiredSource, conflict, data }

class UniversitySearchResult {
  const UniversitySearchResult({
    required this.state,
    required this.items,
    this.message,
  });

  final CatalogResultState state;
  final List<UniversityProgram> items;
  final String? message;

  bool get isEmpty => items.isEmpty;
}

class ScholarshipSearchResult {
  const ScholarshipSearchResult({
    required this.state,
    required this.items,
    this.message,
  });

  final CatalogResultState state;
  final List<ScholarshipListing> items;
  final String? message;

  bool get isEmpty => items.isEmpty;
}

/// Pure search/filter over an in-memory catalog (verified data only).
class UniversityScholarshipCatalog {
  const UniversityScholarshipCatalog({
    this.programs = const [],
    this.scholarships = const [],
  });

  final List<UniversityProgram> programs;
  final List<ScholarshipListing> scholarships;

  UniversitySearchResult searchPrograms(
    UniversitySearchFilter filter, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    if (programs.isEmpty) {
      return const UniversitySearchResult(
        state: CatalogResultState.empty,
        items: [],
        message: 'No verified university programs are loaded.',
      );
    }

    var list = programs;
    final country = filter.countryCode?.trim().toUpperCase();
    if (country != null && country.isNotEmpty) {
      list = list
          .where((p) => p.countryCode.toUpperCase() == country)
          .toList(growable: false);
    }
    if (filter.degreeLevel != null &&
        filter.degreeLevel != DegreeLevel.unknown) {
      list = list
          .where((p) => p.degreeLevel == filter.degreeLevel)
          .toList(growable: false);
    }
    final q = filter.query?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      list = list
          .where(
            (p) =>
                p.institutionName.toLowerCase().contains(q) ||
                p.programName.toLowerCase().contains(q),
          )
          .toList(growable: false);
    }

    if (filter.requireFreshSource) {
      list = list
          .where((p) {
            final s = p.source;
            if (s == null) return false;
            return s.freshness(clock) == EvidenceFreshness.fresh;
          })
          .toList(growable: false);
    }

    if (list.isEmpty) {
      return const UniversitySearchResult(
        state: CatalogResultState.empty,
        items: [],
        message: 'No programs matched the filter.',
      );
    }

    final anyMissingSource = list.any((p) => p.source == null);
    final anyStale = list.any(
      (p) =>
          p.source != null &&
          (p.source!.freshness(clock) == EvidenceFreshness.stale ||
              p.source!.freshness(clock) == EvidenceFreshness.aging),
    );

    CatalogResultState state = CatalogResultState.data;
    String? message;
    if (anyMissingSource) {
      state = CatalogResultState.unknownSource;
      message = 'Some results lack source metadata.';
    } else if (anyStale) {
      state = CatalogResultState.expiredSource;
      message = 'Some results have aging or stale sources.';
    }

    return UniversitySearchResult(state: state, items: list, message: message);
  }

  ScholarshipSearchResult searchScholarships(
    ScholarshipSearchFilter filter, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    if (scholarships.isEmpty) {
      return const ScholarshipSearchResult(
        state: CatalogResultState.empty,
        items: [],
        message: 'No verified scholarships are loaded.',
      );
    }

    var list = scholarships;
    final country = filter.countryCode?.trim().toUpperCase();
    if (country != null && country.isNotEmpty) {
      list = list
          .where((s) => s.countryCode.toUpperCase() == country)
          .toList(growable: false);
    }
    final q = filter.query?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      list = list
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                (s.institutionName?.toLowerCase().contains(q) ?? false),
          )
          .toList(growable: false);
    }
    if (filter.excludeExpiredDeadlines) {
      list = list
          .where((s) => !s.isDeadlinePassed(clock))
          .toList(growable: false);
    }
    if (filter.requireFreshSource) {
      list = list
          .where((s) {
            final src = s.source;
            if (src == null) return false;
            return src.freshness(clock) == EvidenceFreshness.fresh;
          })
          .toList(growable: false);
    }

    if (list.isEmpty) {
      return const ScholarshipSearchResult(
        state: CatalogResultState.empty,
        items: [],
        message: 'No scholarships matched the filter.',
      );
    }

    return ScholarshipSearchResult(state: CatalogResultState.data, items: list);
  }
}
