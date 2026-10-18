// Versioned, deterministic evidence registry for RAD Emigrate.
// Compatible with KnowledgeIntegrityService. No UI coupling.
// Does not invent immigration facts or auto-approve eligibility rules.

import 'knowledge_integrity.dart';

/// Editorial / review workflow status for a registry record.
enum EvidenceReviewStatus {
  /// Source captured; awaiting human editorial review.
  pendingReview,

  /// Human approved for display as descriptive content only.
  approvedDescriptive,

  /// Human approved for use as a curated eligibility rule input.
  approvedForEligibilityRules,

  /// Explicitly rejected; must not be published.
  rejected,

  /// Evidence incomplete or could not be verified.
  missingEvidence,

  /// Open conflict with another source.
  conflicting,

  /// Past validity window or retrieval age policy.
  stale,
}

extension EvidenceReviewStatusX on EvidenceReviewStatus {
  String get key => name;

  static EvidenceReviewStatus fromString(String? value) {
    if (value == null || value.isEmpty) {
      return EvidenceReviewStatus.pendingReview;
    }
    return EvidenceReviewStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EvidenceReviewStatus.pendingReview,
    );
  }

  /// Only these statuses may feed curated eligibility rules.
  bool get mayFeedEligibilityRules =>
      this == EvidenceReviewStatus.approvedForEligibilityRules;

  /// Descriptive catalog text may use approved descriptive content.
  bool get mayPublishDescriptive =>
      this == EvidenceReviewStatus.approvedDescriptive ||
      this == EvidenceReviewStatus.approvedForEligibilityRules;
}

/// One versioned evidence record (source-backed fact or citation).
class EvidenceRecord {
  const EvidenceRecord({
    required this.id,
    required this.topicKey,
    required this.statement,
    required this.source,
    required this.reviewStatus,
    this.programId,
    this.jurisdiction,
    this.excerpt,
    this.publicationDate,
    this.registryVersion = 1,
    this.humanReviewNotes,
  });

  final String id;
  final String topicKey;
  final String statement;
  final KnowledgeSourceIdentity source;
  final EvidenceReviewStatus reviewStatus;
  final String? programId;
  final String? jurisdiction;
  final String? excerpt;
  final DateTime? publicationDate;
  final int registryVersion;
  final String? humanReviewNotes;

  KnowledgeClaim toClaim() => KnowledgeClaim(
    id: id,
    topicKey: topicKey,
    statement: statement,
    sourceId: source.id,
    programId: programId,
    jurisdiction: jurisdiction,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'topicKey': topicKey,
    'statement': statement,
    'source': source.toJson(),
    'reviewStatus': reviewStatus.name,
    'programId': programId,
    'jurisdiction': jurisdiction,
    'excerpt': excerpt,
    'publicationDate': publicationDate?.toIso8601String(),
    'registryVersion': registryVersion,
    'humanReviewNotes': humanReviewNotes,
  };

  factory EvidenceRecord.fromJson(Map<String, dynamic> json) {
    return EvidenceRecord(
      id: json['id'] as String? ?? '',
      topicKey: json['topicKey'] as String? ?? '',
      statement: json['statement'] as String? ?? '',
      source: KnowledgeSourceIdentity.fromJson(
        Map<String, dynamic>.from(json['source'] as Map? ?? const {}),
      ),
      reviewStatus: EvidenceReviewStatusX.fromString(
        json['reviewStatus'] as String?,
      ),
      programId: json['programId'] as String?,
      jurisdiction: json['jurisdiction'] as String?,
      excerpt: json['excerpt'] as String?,
      publicationDate: json['publicationDate'] != null
          ? DateTime.tryParse(json['publicationDate'] as String)
          : null,
      registryVersion: json['registryVersion'] as int? ?? 1,
      humanReviewNotes: json['humanReviewNotes'] as String?,
    );
  }

  List<String> validationErrors() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('missing_id');
    if (topicKey.trim().isEmpty) errors.add('missing_topicKey');
    if (statement.trim().isEmpty) errors.add('missing_statement');
    errors.addAll(KnowledgeIntegrityService.invalidSourceReasons(source));
    return errors;
  }
}

/// Snapshot of the evidence registry (import/export unit).
class EvidenceRegistrySnapshot {
  const EvidenceRegistrySnapshot({
    required this.version,
    required this.generatedAt,
    required this.records,
    this.label,
  });

  final int version;
  final DateTime generatedAt;
  final List<EvidenceRecord> records;
  final String? label;

  Map<String, dynamic> toJson() => {
    'version': version,
    'generatedAt': generatedAt.toIso8601String(),
    'label': label,
    'records': records.map((r) => r.toJson()).toList(),
  };

  factory EvidenceRegistrySnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['records'];
    final list = raw is List
        ? raw
              .map(
                (e) => EvidenceRecord.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
        : <EvidenceRecord>[];
    return EvidenceRegistrySnapshot(
      version: json['version'] as int? ?? 0,
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      label: json['label'] as String?,
      records: list,
    );
  }
}

/// Validation + integrity evaluation over a registry snapshot.
class EvidenceRegistry {
  const EvidenceRegistry({this.integrity = const KnowledgeIntegrityService()});

  final KnowledgeIntegrityService integrity;

  /// Structural validation only.
  List<String> validateRecord(EvidenceRecord record) =>
      record.validationErrors();

  List<String> validateSnapshot(EvidenceRegistrySnapshot snapshot) {
    final errors = <String>[];
    final ids = <String>{};
    for (final r in snapshot.records) {
      final ve = r.validationErrors();
      for (final e in ve) {
        errors.add('${r.id}:$e');
      }
      if (r.id.isNotEmpty && !ids.add(r.id)) {
        errors.add('${r.id}:duplicate_record_id');
      }
    }
    return errors;
  }

  /// Run knowledge integrity over registry sources/claims.
  KnowledgeIntegrityReport evaluateIntegrity(
    EvidenceRegistrySnapshot snapshot, {
    DateTime? now,
  }) {
    final sources = <String, KnowledgeSourceIdentity>{};
    for (final r in snapshot.records) {
      sources[r.source.id] = r.source;
    }
    final claims = snapshot.records.map((r) => r.toClaim()).toList();
    return integrity.evaluate(
      sources: sources.values.toList(),
      claims: claims,
      now: now,
    );
  }

  /// Records approved for eligibility-rule use only.
  List<EvidenceRecord> eligibilityApproved(EvidenceRegistrySnapshot snapshot) {
    return snapshot.records
        .where((r) => r.reviewStatus.mayFeedEligibilityRules)
        .toList(growable: false);
  }

  /// Descriptive-publishable records (never auto-eligibility).
  List<EvidenceRecord> descriptiveApproved(EvidenceRegistrySnapshot snapshot) {
    return snapshot.records
        .where((r) => r.reviewStatus.mayPublishDescriptive)
        .toList(growable: false);
  }

  /// Merge two snapshots deterministically (by record id; later wins).
  EvidenceRegistrySnapshot merge({
    required EvidenceRegistrySnapshot base,
    required EvidenceRegistrySnapshot incoming,
    required DateTime at,
    int? nextVersion,
  }) {
    final byId = <String, EvidenceRecord>{
      for (final r in base.records) r.id: r,
    };
    for (final r in incoming.records) {
      byId[r.id] = r;
    }
    final sorted = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return EvidenceRegistrySnapshot(
      version: nextVersion ?? (base.version + 1),
      generatedAt: at,
      label: incoming.label ?? base.label,
      records: sorted,
    );
  }
}
