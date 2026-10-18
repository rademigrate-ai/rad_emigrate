// Deterministic knowledge integrity layer for RAD Emigrate.
// Classifies sources, detects conflicts, freshness, and human-review needs.
// Never treats AI-generated content as authoritative immigration fact.

/// Authority class of a knowledge source.
enum SourceAuthorityClass {
  /// Official government / immigration authority.
  government,

  /// University or licensed institutional body.
  institutional,

  /// First-party RAD project editorial content.
  radProject,

  /// AI-generated or model-derived text (never authoritative alone).
  aiGenerated,

  /// Unverified third-party or unknown origin.
  unverified,
}

extension SourceAuthorityClassX on SourceAuthorityClass {
  String get key => name;

  /// Government and institutional sources may support eligibility evaluation.
  bool get maySupportEligibility =>
      this == SourceAuthorityClass.government ||
      this == SourceAuthorityClass.institutional;

  bool get isAuthoritative => maySupportEligibility;

  static SourceAuthorityClass fromString(String? value) {
    if (value == null || value.isEmpty) return SourceAuthorityClass.unverified;
    return SourceAuthorityClass.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SourceAuthorityClass.unverified,
    );
  }
}

/// Freshness bucket for evidence rows.
enum KnowledgeFreshness { fresh, aging, expired, unknown }

extension KnowledgeFreshnessX on KnowledgeFreshness {
  String get key => name;

  static KnowledgeFreshness fromString(String? value) {
    if (value == null || value.isEmpty) return KnowledgeFreshness.unknown;
    return KnowledgeFreshness.values.firstWhere(
      (e) => e.name == value,
      orElse: () => KnowledgeFreshness.unknown,
    );
  }
}

/// Structured source identity with canonical URL and validity window.
class KnowledgeSourceIdentity {
  const KnowledgeSourceIdentity({
    required this.id,
    required this.title,
    required this.canonicalUrl,
    required this.authority,
    required this.retrievedAt,
    this.publisher,
    this.jurisdiction,
    this.programIds = const [],
    this.validFrom,
    this.validUntil,
    this.versionLabel,
    this.contentHash,
  });

  final String id;
  final String title;
  final String canonicalUrl;
  final SourceAuthorityClass authority;
  final DateTime retrievedAt;
  final String? publisher;
  final String? jurisdiction;
  final List<String> programIds;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? versionLabel;
  final String? contentHash;

  bool appliesToProgram(String programId) {
    if (programIds.isEmpty) return true;
    return programIds.contains(programId);
  }

  bool appliesToJurisdiction(String? code) {
    if (code == null || code.isEmpty) return true;
    if (jurisdiction == null || jurisdiction!.isEmpty) return true;
    return jurisdiction!.toUpperCase() == code.toUpperCase();
  }

  KnowledgeFreshness freshness(
    DateTime now, {
    Duration agingAfter = const Duration(days: 180),
    Duration expireAfter = const Duration(days: 365),
  }) {
    if (validUntil != null && validUntil!.isBefore(now)) {
      return KnowledgeFreshness.expired;
    }
    if (retrievedAt.isAfter(now)) return KnowledgeFreshness.unknown;
    final age = now.difference(retrievedAt);
    if (age > expireAfter) return KnowledgeFreshness.expired;
    if (age > agingAfter) return KnowledgeFreshness.aging;
    return KnowledgeFreshness.fresh;
  }

  bool get isAuthoritative => authority.isAuthoritative;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'canonicalUrl': canonicalUrl,
    'authority': authority.name,
    'retrievedAt': retrievedAt.toIso8601String(),
    'publisher': publisher,
    'jurisdiction': jurisdiction,
    'programIds': programIds,
    'validFrom': validFrom?.toIso8601String(),
    'validUntil': validUntil?.toIso8601String(),
    'versionLabel': versionLabel,
    'contentHash': contentHash,
  };

  factory KnowledgeSourceIdentity.fromJson(Map<String, dynamic> json) {
    final programsRaw = json['programIds'];
    final programs = programsRaw is List
        ? programsRaw.map((e) => e.toString()).toList()
        : <String>[];
    return KnowledgeSourceIdentity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      canonicalUrl: json['canonicalUrl'] as String? ?? '',
      authority: SourceAuthorityClassX.fromString(json['authority'] as String?),
      retrievedAt:
          DateTime.tryParse(json['retrievedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      publisher: json['publisher'] as String?,
      jurisdiction: json['jurisdiction'] as String?,
      programIds: programs,
      validFrom: json['validFrom'] != null
          ? DateTime.tryParse(json['validFrom'] as String)
          : null,
      validUntil: json['validUntil'] != null
          ? DateTime.tryParse(json['validUntil'] as String)
          : null,
      versionLabel: json['versionLabel'] as String?,
      contentHash: json['contentHash'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeSourceIdentity &&
          id == other.id &&
          canonicalUrl == other.canonicalUrl &&
          contentHash == other.contentHash;

  @override
  int get hashCode => Object.hash(id, canonicalUrl, contentHash);
}

/// A single claim bound to a source (does not invent immigration content).
class KnowledgeClaim {
  const KnowledgeClaim({
    required this.id,
    required this.topicKey,
    required this.statement,
    required this.sourceId,
    this.programId,
    this.jurisdiction,
  });

  final String id;
  final String topicKey;
  final String statement;
  final String sourceId;
  final String? programId;
  final String? jurisdiction;

  Map<String, dynamic> toJson() => {
    'id': id,
    'topicKey': topicKey,
    'statement': statement,
    'sourceId': sourceId,
    'programId': programId,
    'jurisdiction': jurisdiction,
  };

  factory KnowledgeClaim.fromJson(Map<String, dynamic> json) {
    return KnowledgeClaim(
      id: json['id'] as String? ?? '',
      topicKey: json['topicKey'] as String? ?? '',
      statement: json['statement'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      programId: json['programId'] as String?,
      jurisdiction: json['jurisdiction'] as String?,
    );
  }
}

/// Explicit open conflict between two claims on the same topic.
class KnowledgeConflict {
  const KnowledgeConflict({
    required this.topicKey,
    required this.claimIdA,
    required this.claimIdB,
    required this.sourceIdA,
    required this.sourceIdB,
    this.requiresHumanReview = true,
    this.detail,
  });

  final String topicKey;
  final String claimIdA;
  final String claimIdB;
  final String sourceIdA;
  final String sourceIdB;
  final bool requiresHumanReview;
  final String? detail;

  Map<String, dynamic> toJson() => {
    'topicKey': topicKey,
    'claimIdA': claimIdA,
    'claimIdB': claimIdB,
    'sourceIdA': sourceIdA,
    'sourceIdB': sourceIdB,
    'requiresHumanReview': requiresHumanReview,
    'detail': detail,
  };
}

/// Version change between two snapshots of the same source identity.
class SourceVersionChange {
  const SourceVersionChange({
    required this.sourceId,
    required this.previousVersion,
    required this.currentVersion,
    required this.previousHash,
    required this.currentHash,
    required this.changed,
  });

  final String sourceId;
  final String? previousVersion;
  final String? currentVersion;
  final String? previousHash;
  final String? currentHash;
  final bool changed;
}

/// Aggregate integrity report for a claim set + source set.
class KnowledgeIntegrityReport {
  const KnowledgeIntegrityReport({
    required this.sources,
    required this.claims,
    required this.conflicts,
    required this.freshnessBySourceId,
    required this.requiresHumanReview,
    required this.hasInsufficientEvidence,
    required this.hasExpiredAuthoritativeEvidence,
    required this.aiOnlyTopics,
    this.versionChanges = const [],
    this.duplicateSourceIds = const [],
    this.invalidSourceIds = const [],
  });

  final List<KnowledgeSourceIdentity> sources;
  final List<KnowledgeClaim> claims;
  final List<KnowledgeConflict> conflicts;
  final Map<String, KnowledgeFreshness> freshnessBySourceId;
  final bool requiresHumanReview;
  final bool hasInsufficientEvidence;
  final bool hasExpiredAuthoritativeEvidence;
  final List<String> aiOnlyTopics;
  final List<SourceVersionChange> versionChanges;
  final List<String> duplicateSourceIds;
  final List<String> invalidSourceIds;

  Map<String, dynamic> toJson() => {
    'sources': sources.map((s) => s.toJson()).toList(),
    'claims': claims.map((c) => c.toJson()).toList(),
    'conflicts': conflicts.map((c) => c.toJson()).toList(),
    'freshnessBySourceId': freshnessBySourceId.map(
      (k, v) => MapEntry(k, v.name),
    ),
    'requiresHumanReview': requiresHumanReview,
    'hasInsufficientEvidence': hasInsufficientEvidence,
    'hasExpiredAuthoritativeEvidence': hasExpiredAuthoritativeEvidence,
    'aiOnlyTopics': aiOnlyTopics,
    'duplicateSourceIds': duplicateSourceIds,
    'invalidSourceIds': invalidSourceIds,
  };
}

/// Pure integrity engine — no network, no invented facts.
class KnowledgeIntegrityService {
  const KnowledgeIntegrityService();

  /// Canonicalize URL for identity comparison (path trailing slash stripped).
  static String canonicalizeUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return raw.trim().toLowerCase();
    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri(scheme: scheme, host: host, path: path).toString();
  }

  /// Validate minimal source metadata.
  static List<String> invalidSourceReasons(KnowledgeSourceIdentity source) {
    final reasons = <String>[];
    if (source.id.trim().isEmpty) reasons.add('missing_id');
    if (source.title.trim().isEmpty) reasons.add('missing_title');
    if (source.canonicalUrl.trim().isEmpty) {
      reasons.add('missing_url');
    } else {
      final uri = Uri.tryParse(source.canonicalUrl);
      if (uri == null || uri.host.isEmpty) reasons.add('invalid_url');
    }
    return reasons;
  }

  /// Detect duplicate source ids or duplicate canonical URLs.
  static List<String> findDuplicateSourceIds(
    List<KnowledgeSourceIdentity> sources,
  ) {
    final seenIds = <String>{};
    final seenUrls = <String>{};
    final dups = <String>[];
    for (final s in sources) {
      if (s.id.isNotEmpty && !seenIds.add(s.id)) {
        if (!dups.contains(s.id)) dups.add(s.id);
      }
      final url = canonicalizeUrl(s.canonicalUrl);
      if (url.isNotEmpty && !seenUrls.add(url)) {
        if (s.id.isNotEmpty && !dups.contains(s.id)) dups.add(s.id);
      }
    }
    return dups;
  }

  /// Compare two versions of the same source for content/version change.
  static SourceVersionChange compareVersions({
    required KnowledgeSourceIdentity previous,
    required KnowledgeSourceIdentity current,
  }) {
    final changed =
        previous.contentHash != current.contentHash ||
        previous.versionLabel != current.versionLabel;
    return SourceVersionChange(
      sourceId: current.id,
      previousVersion: previous.versionLabel,
      currentVersion: current.versionLabel,
      previousHash: previous.contentHash,
      currentHash: current.contentHash,
      changed: changed,
    );
  }

  /// Detect statement conflicts on the same topicKey across different sources.
  static List<KnowledgeConflict> detectConflicts(List<KnowledgeClaim> claims) {
    final byTopic = <String, List<KnowledgeClaim>>{};
    for (final c in claims) {
      final key = c.topicKey.trim().toLowerCase();
      if (key.isEmpty) continue;
      byTopic.putIfAbsent(key, () => []).add(c);
    }
    final conflicts = <KnowledgeConflict>[];
    for (final entry in byTopic.entries) {
      final list = entry.value;
      if (list.length < 2) continue;
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final a = list[i];
          final b = list[j];
          if (a.sourceId == b.sourceId) continue;
          final sa = a.statement.trim().toLowerCase();
          final sb = b.statement.trim().toLowerCase();
          if (sa.isEmpty || sb.isEmpty) continue;
          if (sa != sb) {
            conflicts.add(
              KnowledgeConflict(
                topicKey: entry.key,
                claimIdA: a.id,
                claimIdB: b.id,
                sourceIdA: a.sourceId,
                sourceIdB: b.sourceId,
                requiresHumanReview: true,
                detail: 'Divergent statements on topic ${entry.key}',
              ),
            );
          }
        }
      }
    }
    return conflicts;
  }

  /// Topics that only have AI-generated source backing.
  static List<String> topicsWithAiOnlyEvidence({
    required List<KnowledgeClaim> claims,
    required Map<String, KnowledgeSourceIdentity> sourcesById,
  }) {
    final byTopic = <String, List<KnowledgeClaim>>{};
    for (final c in claims) {
      byTopic.putIfAbsent(c.topicKey, () => []).add(c);
    }
    final aiOnly = <String>[];
    for (final entry in byTopic.entries) {
      final authorities = entry.value.map((c) {
        final s = sourcesById[c.sourceId];
        return s?.authority ?? SourceAuthorityClass.unverified;
      }).toSet();
      final hasAuthoritative = authorities.any((a) => a.maySupportEligibility);
      final hasAi = authorities.contains(SourceAuthorityClass.aiGenerated);
      if (hasAi && !hasAuthoritative) {
        aiOnly.add(entry.key);
      }
    }
    return aiOnly;
  }

  /// Full integrity evaluation.
  KnowledgeIntegrityReport evaluate({
    required List<KnowledgeSourceIdentity> sources,
    required List<KnowledgeClaim> claims,
    DateTime? now,
    List<KnowledgeSourceIdentity> previousSources = const [],
  }) {
    final clock = now ?? DateTime.now().toUtc();
    final sourcesById = <String, KnowledgeSourceIdentity>{
      for (final s in sources) s.id: s,
    };

    final invalidIds = <String>[];
    for (final s in sources) {
      if (invalidSourceReasons(s).isNotEmpty) invalidIds.add(s.id);
    }

    final dups = findDuplicateSourceIds(sources);
    final conflicts = detectConflicts(claims);

    final freshness = <String, KnowledgeFreshness>{};
    var expiredAuthoritative = false;
    for (final s in sources) {
      final f = s.freshness(clock);
      freshness[s.id] = f;
      if (f == KnowledgeFreshness.expired && s.isAuthoritative) {
        expiredAuthoritative = true;
      }
    }

    final aiOnly = topicsWithAiOnlyEvidence(
      claims: claims,
      sourcesById: sourcesById,
    );

    final prevById = <String, KnowledgeSourceIdentity>{
      for (final s in previousSources) s.id: s,
    };
    final versionChanges = <SourceVersionChange>[];
    for (final s in sources) {
      final prev = prevById[s.id];
      if (prev != null) {
        versionChanges.add(compareVersions(previous: prev, current: s));
      }
    }

    final hasAuthoritativeClaim = claims.any((c) {
      final s = sourcesById[c.sourceId];
      return s != null && s.isAuthoritative;
    });

    final requiresReview =
        conflicts.isNotEmpty ||
        aiOnly.isNotEmpty ||
        expiredAuthoritative ||
        invalidIds.isNotEmpty;

    return KnowledgeIntegrityReport(
      sources: sources,
      claims: claims,
      conflicts: conflicts,
      freshnessBySourceId: freshness,
      requiresHumanReview: requiresReview,
      hasInsufficientEvidence: claims.isEmpty || !hasAuthoritativeClaim,
      hasExpiredAuthoritativeEvidence: expiredAuthoritative,
      aiOnlyTopics: aiOnly,
      versionChanges: versionChanges,
      duplicateSourceIds: dups,
      invalidSourceIds: invalidIds,
    );
  }
}
