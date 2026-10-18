// Deterministic, evidence-aware recommendation foundation for RAD Emigrate.
// Consumes immigration profile + pathway assessment contracts.
// Never fabricates eligibility requirements or approval probabilities.

import 'entities/profile_entity.dart';
import 'immigration_profile_validator.dart';
import 'pathway_assessment.dart';

/// Why a candidate was included or excluded.
enum RecommendationDecision {
  included,
  excludedInsufficientEvidence,
  excludedInsufficientProfile,
  excludedIneligible,
  excludedRequiresReview,
  excludedPreferenceMismatch,
  excludedInvalidMetadata,
}

extension RecommendationDecisionX on RecommendationDecision {
  String get key => name;
}

/// Preference-only ranking signal (not eligibility).
enum PreferenceMatch { strong, partial, none, unknown }

/// One recommendation candidate with transparent explanation.
class ProgramRecommendation {
  const ProgramRecommendation({
    required this.programId,
    required this.decision,
    required this.pathwayOutcome,
    required this.preferenceMatch,
    required this.explanation,
    this.evidence = const [],
    this.rankScore = 0,
  });

  final String programId;
  final RecommendationDecision decision;
  final PathwayOutcome pathwayOutcome;
  final PreferenceMatch preferenceMatch;

  /// Transparent human-readable explanation (no approval probability).
  final String explanation;
  final List<PathwayRuleEvidence> evidence;

  /// Deterministic preference rank only among [included] decisions.
  /// Higher is more preferred; not an eligibility score.
  final int rankScore;

  bool get isIncluded => decision == RecommendationDecision.included;

  Map<String, dynamic> toJson() => {
    'programId': programId,
    'decision': decision.name,
    'pathwayOutcome': pathwayOutcome.name,
    'preferenceMatch': preferenceMatch.name,
    'explanation': explanation,
    'evidence': evidence.map((e) => e.toJson()).toList(),
    'rankScore': rankScore,
  };
}

/// Bundle of recommendations with global status.
class RecommendationReport {
  const RecommendationReport({
    required this.recommendations,
    required this.profileCompletenessPercent,
    required this.hasAnyVerifiedRules,
  });

  final List<ProgramRecommendation> recommendations;
  final int profileCompletenessPercent;
  final bool hasAnyVerifiedRules;

  List<ProgramRecommendation> get included =>
      recommendations.where((r) => r.isIncluded).toList(growable: false);

  Map<String, dynamic> toJson() => {
    'recommendations': recommendations.map((r) => r.toJson()).toList(),
    'profileCompletenessPercent': profileCompletenessPercent,
    'hasAnyVerifiedRules': hasAnyVerifiedRules,
  };
}

/// Deterministic recommendation engine.
///
/// Eligibility is decided only via [PathwayAssessmentService] and curated rules.
/// Preference ranking only reorders eligible options; it never creates eligibility.
class RecommendationEngine {
  const RecommendationEngine({this.pathway = const PathwayAssessmentService()});

  final PathwayAssessmentService pathway;

  RecommendationReport recommend({
    required ImmigrationProfile profile,
    required List<String> candidateProgramIds,
    required List<PathwayEligibilityRule> rules,
    DateTime? now,
  }) {
    final validation = ImmigrationProfileValidator.validate(profile);
    final hasRules = rules.isNotEmpty;
    final recs = <ProgramRecommendation>[];

    // Deterministic order: sort candidate ids then evaluate.
    final programs = List<String>.from(candidateProgramIds)..sort();

    for (final programId in programs) {
      final assessment = pathway.assess(
        profile: profile,
        programId: programId,
        rules: rules,
        now: now,
      );

      final preference = _preferenceMatch(profile, programId);

      switch (assessment.outcome) {
        case PathwayOutcome.insufficientVerifiedEvidence:
          recs.add(
            ProgramRecommendation(
              programId: programId,
              decision: RecommendationDecision.excludedInsufficientEvidence,
              pathwayOutcome: assessment.outcome,
              preferenceMatch: preference,
              explanation:
                  'Excluded: insufficient verified evidence for program $programId.',
              evidence: assessment.evidence,
            ),
          );
        case PathwayOutcome.insufficientInformation:
          recs.add(
            ProgramRecommendation(
              programId: programId,
              decision: RecommendationDecision.excludedInsufficientProfile,
              pathwayOutcome: assessment.outcome,
              preferenceMatch: preference,
              explanation:
                  'Excluded: profile missing required fields for program $programId '
                  '(${assessment.missingFields.map((f) => f.key).join(', ')}).',
              evidence: assessment.evidence,
            ),
          );
        case PathwayOutcome.potentiallyIneligible:
          recs.add(
            ProgramRecommendation(
              programId: programId,
              decision: RecommendationDecision.excludedIneligible,
              pathwayOutcome: assessment.outcome,
              preferenceMatch: preference,
              explanation:
                  'Excluded: profile conflicts with curated rule for $programId.',
              evidence: assessment.evidence,
            ),
          );
        case PathwayOutcome.requiresProfessionalReview:
          recs.add(
            ProgramRecommendation(
              programId: programId,
              decision: RecommendationDecision.excludedRequiresReview,
              pathwayOutcome: assessment.outcome,
              preferenceMatch: preference,
              explanation:
                  'Excluded from auto-rank: requires professional review for $programId.',
              evidence: assessment.evidence,
            ),
          );
        case PathwayOutcome.potentiallyEligible:
          final rank = _preferenceRankScore(preference);
          recs.add(
            ProgramRecommendation(
              programId: programId,
              decision: RecommendationDecision.included,
              pathwayOutcome: assessment.outcome,
              preferenceMatch: preference,
              explanation:
                  'Included: satisfies curated structural rules for $programId. '
                  'Preference match: ${preference.name}. Not an approval guarantee.',
              evidence: assessment.evidence,
              rankScore: rank,
            ),
          );
      }
    }

    // Deterministic sort: included first by rankScore desc, then programId asc;
    // exclusions after, by programId asc.
    recs.sort((a, b) {
      if (a.isIncluded != b.isIncluded) {
        return a.isIncluded ? -1 : 1;
      }
      if (a.isIncluded && b.isIncluded) {
        final cmp = b.rankScore.compareTo(a.rankScore);
        if (cmp != 0) return cmp;
      }
      return a.programId.compareTo(b.programId);
    });

    return RecommendationReport(
      recommendations: recs,
      profileCompletenessPercent: validation.completenessPercent,
      hasAnyVerifiedRules: hasRules,
    );
  }

  /// Preference match uses destinationPreference only (never eligibility).
  static const Map<String, String> _countryAliases = {
    'canada': 'ca',
    'germany': 'de',
    'australia': 'au',
    'united states': 'us',
    'usa': 'us',
    'uk': 'gb',
    'united kingdom': 'gb',
    'iran': 'ir',
  };

  static PreferenceMatch _preferenceMatch(
    ImmigrationProfile profile,
    String programId,
  ) {
    final pref = profile.destinationPreference?.trim().toLowerCase();
    if (pref == null || pref.isEmpty) return PreferenceMatch.unknown;
    final pid = programId.toLowerCase();
    if (pid.contains(pref) || pref.contains(pid)) {
      return PreferenceMatch.strong;
    }
    final alias = _countryAliases[pref];
    if (alias != null &&
        (pid == alias ||
            pid.startsWith('$alias-') ||
            pid.startsWith('${alias}_'))) {
      return PreferenceMatch.partial;
    }
    final prefTokens = pref
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 1);
    final pidTokens = pid
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 1);
    if (prefTokens.any(pidTokens.contains)) return PreferenceMatch.partial;
    return PreferenceMatch.none;
  }

  static int _preferenceRankScore(PreferenceMatch match) {
    switch (match) {
      case PreferenceMatch.strong:
        return 30;
      case PreferenceMatch.partial:
        return 20;
      case PreferenceMatch.none:
        return 10;
      case PreferenceMatch.unknown:
        return 0;
    }
  }
}
