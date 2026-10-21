// Approval gate between evidence registry and PathwayAssessmentService.
// Never auto-converts descriptive research into eligibility rules.

import 'pathway_assessment.dart';
import '../../knowledge/domain/evidence_registry.dart';

/// Explicit editorial approval envelope for a curated rule set.
class CuratedRulePackage {
  const CuratedRulePackage({
    required this.packageId,
    required this.rules,
    required this.editorialApproved,
    required this.approvedAt,
    this.approverLabel,
    this.evidenceRecordIds = const [],
    this.notes,
  });

  final String packageId;
  final List<PathwayEligibilityRule> rules;

  /// Must be true before rules are exposed to recommendation/pathway engines.
  final bool editorialApproved;
  final DateTime? approvedAt;
  final String? approverLabel;
  final List<String> evidenceRecordIds;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'packageId': packageId,
    'editorialApproved': editorialApproved,
    'approvedAt': approvedAt?.toIso8601String(),
    'approverLabel': approverLabel,
    'evidenceRecordIds': evidenceRecordIds,
    'notes': notes,
    'rules': rules.map((r) => r.toJson()).toList(),
  };
}

/// Fail-closed loader: unapproved packages yield empty rule lists.
class CuratedRulesGate {
  const CuratedRulesGate();

  /// Returns rules only when [package.editorialApproved] is true.
  List<PathwayEligibilityRule> loadApproved(CuratedRulePackage package) {
    if (!package.editorialApproved || package.approvedAt == null) {
      return const [];
    }
    return List<PathwayEligibilityRule>.unmodifiable(package.rules);
  }

  /// Optional cross-check: package may only activate if evidence records
  /// are eligibility-approved in the registry snapshot.
  List<PathwayEligibilityRule> loadIfEvidenceSupports({
    required CuratedRulePackage package,
    required EvidenceRegistrySnapshot registry,
  }) {
    if (!package.editorialApproved || package.approvedAt == null) {
      return const [];
    }
    if (package.evidenceRecordIds.isEmpty) {
      // Explicit package approval without linked evidence is still allowed
      // only when editorialApproved — but fail-closed on empty rules.
      return loadApproved(package);
    }
    final approvedIds = const EvidenceRegistry()
        .eligibilityApproved(registry)
        .map((r) => r.id)
        .toSet();
    final missing = package.evidenceRecordIds
        .where((id) => !approvedIds.contains(id))
        .toList();
    if (missing.isNotEmpty) return const [];
    return loadApproved(package);
  }
}
