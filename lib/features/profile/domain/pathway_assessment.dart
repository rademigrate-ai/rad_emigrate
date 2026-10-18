// Evidence-based pathway assessment outcomes for RAD Emigrate.
// Deterministic structural checks are separate from authoritative rule evaluation.
// Never invents visa eligibility thresholds or government outcomes.

import 'entities/profile_entity.dart';
import 'immigration_profile_validator.dart';

/// Explicit assessment outcome. No intermediate "score" that implies legal advice.
enum PathwayOutcome {
  /// Verified rules exist and profile facts satisfy them (rare without curated rules).
  potentiallyEligible,

  /// Profile lacks required fields to evaluate against verified rules.
  insufficientInformation,

  /// Verified rules exist and profile facts conflict with them.
  potentiallyIneligible,

  /// Case requires human professional review (complex / multi-factor / conflict).
  requiresProfessionalReview,

  /// No authoritative rule set is available for this jurisdiction/program pair.
  insufficientVerifiedEvidence,
}

extension PathwayOutcomeX on PathwayOutcome {
  String get key => name;

  static PathwayOutcome fromString(String? value) {
    if (value == null || value.isEmpty) {
      return PathwayOutcome.insufficientVerifiedEvidence;
    }
    return PathwayOutcome.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PathwayOutcome.insufficientVerifiedEvidence,
    );
  }
}

/// Metadata for a single authoritative eligibility rule citation.
class PathwayRuleEvidence {
  const PathwayRuleEvidence({
    required this.jurisdiction,
    required this.title,
    required this.sourceUrl,
    required this.retrievedAt,
    this.validFrom,
    this.validUntil,
    this.publisher,
    this.notes,
  });

  final String jurisdiction;
  final String title;
  final String sourceUrl;
  final DateTime retrievedAt;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? publisher;
  final String? notes;

  bool isFresh(DateTime now, {Duration maxAge = const Duration(days: 365)}) {
    if (validUntil != null && validUntil!.isBefore(now)) return false;
    return !retrievedAt.isBefore(now.subtract(maxAge));
  }

  Map<String, dynamic> toJson() => {
    'jurisdiction': jurisdiction,
    'title': title,
    'sourceUrl': sourceUrl,
    'retrievedAt': retrievedAt.toIso8601String(),
    'validFrom': validFrom?.toIso8601String(),
    'validUntil': validUntil?.toIso8601String(),
    'publisher': publisher,
    'notes': notes,
  };

  factory PathwayRuleEvidence.fromJson(Map<String, dynamic> json) {
    return PathwayRuleEvidence(
      jurisdiction: json['jurisdiction'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      retrievedAt:
          DateTime.tryParse(json['retrievedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      validFrom: json['validFrom'] != null
          ? DateTime.tryParse(json['validFrom'] as String)
          : null,
      validUntil: json['validUntil'] != null
          ? DateTime.tryParse(json['validUntil'] as String)
          : null,
      publisher: json['publisher'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

/// One curated, human-approved eligibility rule (not inferred by AI).
class PathwayEligibilityRule {
  const PathwayEligibilityRule({
    required this.id,
    required this.programId,
    required this.jurisdiction,
    required this.requiredFields,
    required this.evidence,
    this.disqualifyingFieldPredicates = const {},
    this.requiresProfessionalReview = false,
  });

  final String id;
  final String programId;
  final String jurisdiction;

  /// Profile fields that must be [ProfileFieldStatus.provided] to evaluate.
  final Set<ImmigrationProfileField> requiredFields;

  /// Optional field → values that, if matched (case-insensitive), force ineligible.
  /// Only used when the rule is explicitly curated; empty by default.
  final Map<ImmigrationProfileField, Set<String>> disqualifyingFieldPredicates;

  final PathwayRuleEvidence evidence;
  final bool requiresProfessionalReview;

  Map<String, dynamic> toJson() => {
    'id': id,
    'programId': programId,
    'jurisdiction': jurisdiction,
    'requiredFields': requiredFields.map((f) => f.key).toList(),
    'disqualifyingFieldPredicates': disqualifyingFieldPredicates.map(
      (k, v) => MapEntry(k.key, v.toList()),
    ),
    'evidence': evidence.toJson(),
    'requiresProfessionalReview': requiresProfessionalReview,
  };
}

/// Result of pathway assessment against zero or more curated rules.
class PathwayAssessmentResult {
  const PathwayAssessmentResult({
    required this.outcome,
    required this.programId,
    required this.profileCompletenessPercent,
    required this.missingFields,
    required this.invalidFields,
    this.matchedRuleId,
    this.evidence = const [],
    this.rationale = '',
  });

  final PathwayOutcome outcome;
  final String programId;
  final int profileCompletenessPercent;
  final List<ImmigrationProfileField> missingFields;
  final List<ImmigrationProfileField> invalidFields;
  final String? matchedRuleId;
  final List<PathwayRuleEvidence> evidence;
  final String rationale;

  Map<String, dynamic> toJson() => {
    'outcome': outcome.name,
    'programId': programId,
    'profileCompletenessPercent': profileCompletenessPercent,
    'missingFields': missingFields.map((f) => f.key).toList(),
    'invalidFields': invalidFields.map((f) => f.key).toList(),
    'matchedRuleId': matchedRuleId,
    'evidence': evidence.map((e) => e.toJson()).toList(),
    'rationale': rationale,
  };
}

/// Assesses a profile against curated pathway rules only.
///
/// If [rules] is empty or none match [programId], returns
/// [PathwayOutcome.insufficientVerifiedEvidence].
class PathwayAssessmentService {
  const PathwayAssessmentService();

  PathwayAssessmentResult assess({
    required ImmigrationProfile profile,
    required String programId,
    required List<PathwayEligibilityRule> rules,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    final validation = ImmigrationProfileValidator.validate(profile);
    final candidates = rules
        .where((r) => r.programId == programId)
        .toList(growable: false);

    if (candidates.isEmpty) {
      return PathwayAssessmentResult(
        outcome: PathwayOutcome.insufficientVerifiedEvidence,
        programId: programId,
        profileCompletenessPercent: validation.completenessPercent,
        missingFields: validation.missingFields,
        invalidFields: validation.invalidFields,
        rationale:
            'No curated eligibility rules are registered for this program. '
            'Insufficient verified evidence to assess pathway eligibility.',
      );
    }

    // Prefer rules with fresh evidence; stale rules still surface for review.
    final fresh = candidates
        .where((r) => r.evidence.isFresh(clock))
        .toList(growable: false);
    final working = fresh.isNotEmpty ? fresh : candidates;

    // If any matching rule requires professional review, escalate.
    final reviewRules = working
        .where((r) => r.requiresProfessionalReview)
        .toList();
    if (reviewRules.isNotEmpty) {
      return PathwayAssessmentResult(
        outcome: PathwayOutcome.requiresProfessionalReview,
        programId: programId,
        profileCompletenessPercent: validation.completenessPercent,
        missingFields: validation.missingFields,
        invalidFields: validation.invalidFields,
        matchedRuleId: reviewRules.first.id,
        evidence: reviewRules.map((r) => r.evidence).toList(),
        rationale: 'Registered rule(s) require professional human review for this program.',
      );
    }

    // Structural completeness against the union of required fields.
    final required = <ImmigrationProfileField>{};
    for (final r in working) {
      required.addAll(r.requiredFields);
    }
    final missingForRules = <ImmigrationProfileField>[];
    final invalidForRules = <ImmigrationProfileField>[];
    for (final field in required) {
      final status = ImmigrationProfileValidator.statusOf(profile, field);
      if (status == ProfileFieldStatus.notProvided ||
          status == ProfileFieldStatus.unknown) {
        missingForRules.add(field);
      } else if (status == ProfileFieldStatus.invalid) {
        invalidForRules.add(field);
      }
    }
    if (missingForRules.isNotEmpty || invalidForRules.isNotEmpty) {
      return PathwayAssessmentResult(
        outcome: PathwayOutcome.insufficientInformation,
        programId: programId,
        profileCompletenessPercent: validation.completenessPercent,
        missingFields: missingForRules,
        invalidFields: invalidForRules,
        evidence: working.map((r) => r.evidence).toList(),
        rationale: 'Profile is missing or has invalid fields required by curated rules.',
      );
    }

    // Disqualifying predicates (only when explicitly curated on a rule).
    for (final rule in working) {
      for (final entry in rule.disqualifyingFieldPredicates.entries) {
        final value = _fieldValue(profile, entry.key);
        if (value == null || value.isEmpty) continue;
        final normalized = value.trim().toLowerCase();
        final hits = entry.value.map((e) => e.trim().toLowerCase()).toSet();
        if (hits.contains(normalized)) {
          return PathwayAssessmentResult(
            outcome: PathwayOutcome.potentiallyIneligible,
            programId: programId,
            profileCompletenessPercent: validation.completenessPercent,
            missingFields: const [],
            invalidFields: const [],
            matchedRuleId: rule.id,
            evidence: [rule.evidence],
            rationale:
                'Profile value conflicts with a curated disqualifying condition '
                'on rule ${rule.id}.',
          );
        }
      }
    }

    // All required fields present and no disqualifiers → potentially eligible
    // under the curated rule set only (not a guarantee of approval).
    return PathwayAssessmentResult(
      outcome: PathwayOutcome.potentiallyEligible,
      programId: programId,
      profileCompletenessPercent: validation.completenessPercent,
      missingFields: const [],
      invalidFields: const [],
      matchedRuleId: working.first.id,
      evidence: working.map((r) => r.evidence).toList(),
      rationale:
          'Profile satisfies structural requirements of curated rule(s). '
          'This is not a visa approval guarantee.',
    );
  }

  static String? _fieldValue(
    ImmigrationProfile profile,
    ImmigrationProfileField field,
  ) {
    switch (field) {
      case ImmigrationProfileField.fullName:
        return profile.fullName;
      case ImmigrationProfileField.email:
        return profile.email;
      case ImmigrationProfileField.phone:
        return profile.phone;
      case ImmigrationProfileField.nationality:
        return profile.nationality;
      case ImmigrationProfileField.education:
        return profile.education;
      case ImmigrationProfileField.workExperience:
        return profile.workExperience;
      case ImmigrationProfileField.languages:
        return profile.languages.isEmpty ? null : profile.languages.join(',');
      case ImmigrationProfileField.destinationPreference:
        return profile.destinationPreference;
      case ImmigrationProfileField.maritalStatus:
        return profile.maritalStatus;
    }
  }
}
