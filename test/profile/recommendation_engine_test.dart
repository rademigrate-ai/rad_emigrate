import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/profile/domain/entities/profile_entity.dart';
import 'package:rad_emigrate/features/profile/domain/pathway_assessment.dart';
import 'package:rad_emigrate/features/profile/domain/recommendation_engine.dart';

void main() {
  const engine = RecommendationEngine();
  final now = DateTime.utc(2026, 10, 18);

  PathwayEligibilityRule rule({
    required String programId,
    String id = 'r1',
    Set<ImmigrationProfileField> required = const {
      ImmigrationProfileField.nationality,
    },
    Map<ImmigrationProfileField, Set<String>> disqualifiers = const {},
    bool review = false,
  }) {
    return PathwayEligibilityRule(
      id: id,
      programId: programId,
      jurisdiction: 'CA',
      requiredFields: required,
      disqualifyingFieldPredicates: disqualifiers,
      requiresProfessionalReview: review,
      evidence: PathwayRuleEvidence(
        jurisdiction: 'CA',
        title: 'Official page',
        sourceUrl: 'https://www.canada.ca/x',
        retrievedAt: now.subtract(const Duration(days: 5)),
      ),
    );
  }

  group('RecommendationEngine', () {
    test('no rules excludes all with insufficient evidence', () {
      const profile = ImmigrationProfile(
        nationality: 'IR',
        destinationPreference: 'Canada',
      );
      final report = engine.recommend(
        profile: profile,
        candidateProgramIds: ['ca-express', 'ca-study'],
        rules: const [],
        now: now,
      );
      expect(report.hasAnyVerifiedRules, isFalse);
      expect(report.included, isEmpty);
      expect(
        report.recommendations.every(
          (r) =>
              r.decision == RecommendationDecision.excludedInsufficientEvidence,
        ),
        isTrue,
      );
    });

    test('eligible preferred program ranks above eligible non-preferred', () {
      const profile = ImmigrationProfile(
        nationality: 'IR',
        destinationPreference: 'canada',
      );
      final rules = [
        rule(programId: 'ca-express', id: 'r-express'),
        rule(programId: 'de-study', id: 'r-de'),
      ];
      final report = engine.recommend(
        profile: profile,
        candidateProgramIds: ['de-study', 'ca-express'],
        rules: rules,
        now: now,
      );
      expect(report.included.length, 2);
      // Equal preference rank → deterministic programId ascending among included.
      expect(report.included.first.programId, 'ca-express');
      expect(report.included.last.programId, 'de-study');
    });

    test('determinism: same inputs same order', () {
      const profile = ImmigrationProfile(nationality: 'IR');
      final rules = [
        rule(programId: 'b-prog', id: 'rb'),
        rule(programId: 'a-prog', id: 'ra'),
      ];
      final r1 = engine.recommend(
        profile: profile,
        candidateProgramIds: ['b-prog', 'a-prog'],
        rules: rules,
        now: now,
      );
      final r2 = engine.recommend(
        profile: profile,
        candidateProgramIds: ['a-prog', 'b-prog'],
        rules: rules,
        now: now,
      );
      expect(
        r1.recommendations.map((e) => e.programId).toList(),
        r2.recommendations.map((e) => e.programId).toList(),
      );
    });

    test('ineligible excluded with explanation', () {
      const profile = ImmigrationProfile(nationality: 'XX');
      final report = engine.recommend(
        profile: profile,
        candidateProgramIds: ['ca-express'],
        rules: [
          rule(
            programId: 'ca-express',
            disqualifiers: {
              ImmigrationProfileField.nationality: {'xx'},
            },
          ),
        ],
        now: now,
      );
      expect(report.included, isEmpty);
      expect(
        report.recommendations.first.decision,
        RecommendationDecision.excludedIneligible,
      );
      expect(report.recommendations.first.explanation, contains('Excluded'));
    });

    test('missing profile fields exclude from auto-include', () {
      const profile = ImmigrationProfile();
      final report = engine.recommend(
        profile: profile,
        candidateProgramIds: ['ca-express'],
        rules: [rule(programId: 'ca-express')],
        now: now,
      );
      expect(
        report.recommendations.first.decision,
        RecommendationDecision.excludedInsufficientProfile,
      );
    });
  });
}
