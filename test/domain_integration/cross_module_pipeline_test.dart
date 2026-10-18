import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/applications/domain/case_lifecycle.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/case_checklist.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/features/knowledge/domain/knowledge_integrity.dart';
import 'package:rad_emigrate/features/profile/domain/entities/profile_entity.dart';
import 'package:rad_emigrate/features/profile/domain/immigration_profile_validator.dart';
import 'package:rad_emigrate/features/profile/domain/pathway_assessment.dart';
import 'package:rad_emigrate/features/profile/domain/recommendation_engine.dart';
import 'package:rad_emigrate/features/visa/domain/entities/university_scholarship.dart';

/// Cross-module domain pipeline:
/// Profile → Validation → Pathway → Knowledge → Recommendation → Case lifecycle
void main() {
  final now = DateTime.utc(2026, 10, 18, 12);

  ImmigrationProfile completeProfile() => const ImmigrationProfile(
    fullName: 'Test User',
    email: 'user@example.com',
    phone: '+14155550100',
    nationality: 'IR',
    education: 'Bachelor',
    workExperience: '5 years',
    languages: ['fa', 'en'],
    destinationPreference: 'canada',
    maritalStatus: 'single',
  );

  PathwayEligibilityRule curatedRule({
    String programId = 'ca-express',
    bool review = false,
    Map<ImmigrationProfileField, Set<String>> disqualifiers = const {},
  }) {
    return PathwayEligibilityRule(
      id: 'rule-$programId',
      programId: programId,
      jurisdiction: 'CA',
      requiredFields: const {
        ImmigrationProfileField.nationality,
        ImmigrationProfileField.education,
      },
      disqualifyingFieldPredicates: disqualifiers,
      requiresProfessionalReview: review,
      evidence: PathwayRuleEvidence(
        jurisdiction: 'CA',
        title: 'Official program page',
        sourceUrl: 'https://www.canada.ca/program',
        retrievedAt: now.subtract(const Duration(days: 7)),
        publisher: 'IRCC',
      ),
    );
  }

  group('serialization round-trips across modules', () {
    test('ImmigrationProfile JSON stable', () {
      final p = completeProfile().markUnknown(ImmigrationProfileField.phone);
      final restored = ImmigrationProfile.fromJson(p.toJson());
      expect(restored, p);
      expect(
        restored.unknownFields.contains(ImmigrationProfileField.phone),
        isTrue,
      );
    });

    test('PathwayAssessmentResult JSON keys present', () {
      final result = const PathwayAssessmentService().assess(
        profile: completeProfile(),
        programId: 'ca-express',
        rules: [curatedRule()],
        now: now,
      );
      final json = result.toJson();
      expect(json['outcome'], 'potentiallyEligible');
      expect(json['programId'], 'ca-express');
      expect(json['evidence'], isA<List>());
    });

    test('KnowledgeIntegrityReport JSON serializes', () {
      final report = const KnowledgeIntegrityService().evaluate(
        sources: [
          KnowledgeSourceIdentity(
            id: 's1',
            title: 'IRCC',
            canonicalUrl: 'https://www.canada.ca/x',
            authority: SourceAuthorityClass.government,
            retrievedAt: now,
            jurisdiction: 'CA',
          ),
        ],
        claims: [
          const KnowledgeClaim(
            id: 'c1',
            topicKey: 'fee',
            statement: '150 CAD',
            sourceId: 's1',
          ),
        ],
        now: now,
      );
      final json = report.toJson();
      expect(json['hasInsufficientEvidence'], isFalse);
      expect(json['sources'], isA<List>());
    });

    test('RecommendationReport JSON serializes', () {
      final report = const RecommendationEngine().recommend(
        profile: completeProfile(),
        candidateProgramIds: ['ca-express'],
        rules: [curatedRule()],
        now: now,
      );
      final json = report.toJson();
      expect(json['hasAnyVerifiedRules'], isTrue);
      expect((json['recommendations'] as List).length, 1);
    });
  });

  group('pipeline: profile → assess → recommend → case', () {
    test('happy path with curated rule produces included recommendation', () {
      final profile = completeProfile();
      final validation = ImmigrationProfileValidator.validate(profile);
      expect(validation.isStructurallyComplete, isTrue);

      final assessment = const PathwayAssessmentService().assess(
        profile: profile,
        programId: 'ca-express',
        rules: [curatedRule()],
        now: now,
      );
      expect(assessment.outcome, PathwayOutcome.potentiallyEligible);

      final recs = const RecommendationEngine().recommend(
        profile: profile,
        candidateProgramIds: ['ca-express', 'unknown-prog'],
        rules: [curatedRule()],
        now: now,
      );
      expect(recs.included.map((e) => e.programId), ['ca-express']);
      expect(
        recs.recommendations
            .firstWhere((r) => r.programId == 'unknown-prog')
            .decision,
        RecommendationDecision.excludedInsufficientEvidence,
      );

      // Case lifecycle from recommendation decision
      final app = VisaApplication(
        id: 'case-1',
        userId: 'user-a',
        title: 'Express Entry',
        programName: 'ca-express',
        country: 'CA',
        status: ApplicationStatus.draft,
        updatedAt: now,
      );
      final checklist = CaseChecklist(
        caseId: 'case-1',
        items: [
          CaseChecklistItem(
            id: 'doc-1',
            title: 'Passport',
            dueDate: now.add(const Duration(days: 3)),
          ),
        ],
      );
      var immigrationCase = ImmigrationCase(
        application: app,
        checklist: checklist,
      );

      const lifecycle = CaseLifecycleService();
      immigrationCase = lifecycle.transitionApplicationStatus(
        case_: immigrationCase,
        actorUserId: 'user-a',
        next: ApplicationStatus.submitted,
        nowUtc: now,
        historyId: 'h1',
      );
      expect(immigrationCase.application.status, ApplicationStatus.submitted);
      expect(immigrationCase.history, isNotEmpty);

      final progress = lifecycle.progress(immigrationCase, nowUtc: now);
      expect(progress.total, 1);
      expect(progress.completed, 0);
    });

    test('repeated calls are deterministic', () {
      final profile = completeProfile();
      final rules = [curatedRule(), curatedRule(programId: 'ca-study')];
      final a = const RecommendationEngine().recommend(
        profile: profile,
        candidateProgramIds: ['ca-study', 'ca-express'],
        rules: rules,
        now: now,
      );
      final b = const RecommendationEngine().recommend(
        profile: profile,
        candidateProgramIds: ['ca-express', 'ca-study'],
        rules: rules,
        now: now,
      );
      expect(
        a.recommendations.map((e) => '${e.programId}:${e.decision.name}'),
        b.recommendations.map((e) => '${e.programId}:${e.decision.name}'),
      );
    });

    test('knowledge conflict blocks treating AI-only as evidence', () {
      final sources = [
        KnowledgeSourceIdentity(
          id: 'ai1',
          title: 'Model output',
          canonicalUrl: 'https://ai.local/generated',
          authority: SourceAuthorityClass.aiGenerated,
          retrievedAt: now,
        ),
      ];
      final claims = [
        const KnowledgeClaim(
          id: 'c1',
          topicKey: 'eligibility',
          statement: 'Guaranteed approval',
          sourceId: 'ai1',
        ),
      ];
      final report = const KnowledgeIntegrityService().evaluate(
        sources: sources,
        claims: claims,
        now: now,
      );
      expect(report.hasInsufficientEvidence, isTrue);
      expect(report.aiOnlyTopics, contains('eligibility'));
      expect(report.requiresHumanReview, isTrue);
    });

    test('empty university catalog fails closed', () {
      const catalog = UniversityScholarshipCatalog();
      final result = catalog.searchPrograms(
        const UniversitySearchFilter(countryCode: 'CA'),
        now: now,
      );
      expect(result.state, CatalogResultState.empty);
      expect(result.items, isEmpty);
    });
  });

  group('ownership across case lifecycle', () {
    test('user B cannot mutate user A case', () {
      final app = VisaApplication(
        id: 'c1',
        userId: 'user-a',
        title: 't',
        programName: 'p',
        country: 'CA',
        status: ApplicationStatus.draft,
        updatedAt: now,
      );
      final c = ImmigrationCase(
        application: app,
        checklist: const CaseChecklist(caseId: 'c1', items: []),
      );
      expect(
        () => const CaseLifecycleService().transitionApplicationStatus(
          case_: c,
          actorUserId: 'user-b',
          next: ApplicationStatus.submitted,
          nowUtc: now,
        ),
        throwsA(
          isA<CaseLifecycleException>().having(
            (e) => e.code,
            'code',
            'ownership_denied',
          ),
        ),
      );
    });
  });
}
