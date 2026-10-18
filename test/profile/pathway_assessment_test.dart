import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/profile/domain/entities/profile_entity.dart';
import 'package:rad_emigrate/features/profile/domain/pathway_assessment.dart';

void main() {
  const service = PathwayAssessmentService();
  final now = DateTime.utc(2026, 10, 18);

  PathwayEligibilityRule rule({
    String programId = 'ca-express',
    Set<ImmigrationProfileField> required = const {
      ImmigrationProfileField.nationality,
      ImmigrationProfileField.education,
    },
    Map<ImmigrationProfileField, Set<String>> disqualifiers = const {},
    bool review = false,
    DateTime? retrievedAt,
  }) {
    return PathwayEligibilityRule(
      id: 'rule-1',
      programId: programId,
      jurisdiction: 'CA',
      requiredFields: required,
      disqualifyingFieldPredicates: disqualifiers,
      requiresProfessionalReview: review,
      evidence: PathwayRuleEvidence(
        jurisdiction: 'CA',
        title: 'IRCC program page',
        sourceUrl: 'https://www.canada.ca/example',
        retrievedAt: retrievedAt ?? now.subtract(const Duration(days: 30)),
        publisher: 'IRCC',
      ),
    );
  }

  group('PathwayAssessmentService', () {
    test('no rules → insufficientVerifiedEvidence', () {
      const profile = ImmigrationProfile(nationality: 'IR');
      final result = service.assess(
        profile: profile,
        programId: 'ca-express',
        rules: const [],
        now: now,
      );
      expect(result.outcome, PathwayOutcome.insufficientVerifiedEvidence);
      expect(result.matchedRuleId, isNull);
    });

    test('missing required fields → insufficientInformation', () {
      const profile = ImmigrationProfile(nationality: 'IR');
      final result = service.assess(
        profile: profile,
        programId: 'ca-express',
        rules: [rule()],
        now: now,
      );
      expect(result.outcome, PathwayOutcome.insufficientInformation);
      expect(result.missingFields, contains(ImmigrationProfileField.education));
      expect(result.evidence, isNotEmpty);
    });

    test('complete profile with rule → potentiallyEligible', () {
      const profile = ImmigrationProfile(
        nationality: 'IR',
        education: 'Bachelor',
      );
      final result = service.assess(
        profile: profile,
        programId: 'ca-express',
        rules: [rule()],
        now: now,
      );
      expect(result.outcome, PathwayOutcome.potentiallyEligible);
      expect(result.matchedRuleId, 'rule-1');
      expect(result.rationale, contains('not a visa approval guarantee'));
    });

    test('disqualifying predicate → potentiallyIneligible', () {
      const profile = ImmigrationProfile(
        nationality: 'XX',
        education: 'Bachelor',
      );
      final result = service.assess(
        profile: profile,
        programId: 'ca-express',
        rules: [
          rule(
            disqualifiers: {
              ImmigrationProfileField.nationality: {'xx'},
            },
          ),
        ],
        now: now,
      );
      expect(result.outcome, PathwayOutcome.potentiallyIneligible);
    });

    test('requiresProfessionalReview flag escalates', () {
      const profile = ImmigrationProfile(
        nationality: 'IR',
        education: 'Bachelor',
      );
      final result = service.assess(
        profile: profile,
        programId: 'ca-express',
        rules: [rule(review: true)],
        now: now,
      );
      expect(result.outcome, PathwayOutcome.requiresProfessionalReview);
    });

    test('wrong programId → insufficientVerifiedEvidence', () {
      const profile = ImmigrationProfile(
        nationality: 'IR',
        education: 'Bachelor',
      );
      final result = service.assess(
        profile: profile,
        programId: 'other-program',
        rules: [rule(programId: 'ca-express')],
        now: now,
      );
      expect(result.outcome, PathwayOutcome.insufficientVerifiedEvidence);
    });
  });
}
