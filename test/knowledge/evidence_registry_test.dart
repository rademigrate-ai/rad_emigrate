import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/knowledge/domain/evidence_registry.dart';
import 'package:rad_emigrate/features/knowledge/domain/knowledge_integrity.dart';
import 'package:rad_emigrate/features/profile/domain/curated_rules_gate.dart';
import 'package:rad_emigrate/features/profile/domain/entities/profile_entity.dart';
import 'package:rad_emigrate/features/profile/domain/pathway_assessment.dart';
import 'package:rad_emigrate/features/profile/domain/recommendation_engine.dart';

void main() {
  final now = DateTime.utc(2026, 10, 18, 15);
  const registry = EvidenceRegistry();

  KnowledgeSourceIdentity gov({
    String id = 'src1',
    String url = 'https://www.canada.ca/example',
  }) {
    return KnowledgeSourceIdentity(
      id: id,
      title: 'IRCC',
      canonicalUrl: url,
      authority: SourceAuthorityClass.government,
      retrievedAt: now,
      jurisdiction: 'CA',
    );
  }

  group('EvidenceRecord validation', () {
    test('invalid record reports errors', () {
      final bad = EvidenceRecord(
        id: '',
        topicKey: '',
        statement: '',
        source: KnowledgeSourceIdentity(
          id: '',
          title: '',
          canonicalUrl: 'bad',
          authority: SourceAuthorityClass.unverified,
          retrievedAt: now,
        ),
        reviewStatus: EvidenceReviewStatus.pendingReview,
      );
      expect(bad.validationErrors(), isNotEmpty);
    });

    test('valid record has no errors', () {
      final ok = EvidenceRecord(
        id: 'e1',
        topicKey: 'fee',
        statement: 'See IRCC',
        source: gov(),
        reviewStatus: EvidenceReviewStatus.pendingReview,
      );
      expect(ok.validationErrors(), isEmpty);
    });
  });

  group('snapshot import/export determinism', () {
    test('toJson/fromJson round-trip', () {
      final snap = EvidenceRegistrySnapshot(
        version: 1,
        generatedAt: now,
        label: 't',
        records: [
          EvidenceRecord(
            id: 'e1',
            topicKey: 't',
            statement: 's',
            source: gov(),
            reviewStatus: EvidenceReviewStatus.pendingReview,
            programId: 'ca-study-permit',
            jurisdiction: 'CA',
          ),
        ],
      );
      final restored = EvidenceRegistrySnapshot.fromJson(snap.toJson());
      expect(restored.version, 1);
      expect(restored.records.length, 1);
      expect(restored.records.first.id, 'e1');
    });

    test('merge is deterministic by id', () {
      final base = EvidenceRegistrySnapshot(
        version: 1,
        generatedAt: now,
        records: [
          EvidenceRecord(
            id: 'b',
            topicKey: 't',
            statement: 'old',
            source: gov(id: 's1'),
            reviewStatus: EvidenceReviewStatus.pendingReview,
          ),
          EvidenceRecord(
            id: 'a',
            topicKey: 't',
            statement: 'a',
            source: gov(id: 's2', url: 'https://www.canada.ca/a'),
            reviewStatus: EvidenceReviewStatus.pendingReview,
          ),
        ],
      );
      final incoming = EvidenceRegistrySnapshot(
        version: 2,
        generatedAt: now,
        records: [
          EvidenceRecord(
            id: 'b',
            topicKey: 't',
            statement: 'new',
            source: gov(id: 's1'),
            reviewStatus: EvidenceReviewStatus.approvedDescriptive,
          ),
        ],
      );
      final merged = registry.merge(base: base, incoming: incoming, at: now);
      expect(merged.records.map((e) => e.id).toList(), ['a', 'b']);
      expect(merged.records.firstWhere((e) => e.id == 'b').statement, 'new');
    });

    test('duplicate record ids flagged', () {
      final snap = EvidenceRegistrySnapshot(
        version: 1,
        generatedAt: now,
        records: [
          EvidenceRecord(
            id: 'dup',
            topicKey: 't',
            statement: '1',
            source: gov(),
            reviewStatus: EvidenceReviewStatus.pendingReview,
          ),
          EvidenceRecord(
            id: 'dup',
            topicKey: 't',
            statement: '2',
            source: gov(url: 'https://www.canada.ca/other'),
            reviewStatus: EvidenceReviewStatus.pendingReview,
          ),
        ],
      );
      expect(
        registry.validateSnapshot(snap),
        contains('dup:duplicate_record_id'),
      );
    });
  });

  group('seed file load', () {
    test('docs/seed/evidence_registry_v1.json parses and validates', () {
      final path = File('docs/seed/evidence_registry_v1.json');
      expect(path.existsSync(), isTrue);
      final snap = EvidenceRegistrySnapshot.fromJson(
        jsonDecode(path.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(snap.records, isNotEmpty);
      expect(registry.validateSnapshot(snap), isEmpty);
      // Seed is pending review — not eligibility-approved
      expect(registry.eligibilityApproved(snap), isEmpty);
      final integrity = registry.evaluateIntegrity(snap, now: now);
      expect(integrity.hasInsufficientEvidence, isFalse);
    });
  });

  group('CuratedRulesGate fail-closed', () {
    test('unapproved package yields empty rules', () {
      final package = CuratedRulePackage(
        packageId: 'p1',
        editorialApproved: false,
        approvedAt: now,
        rules: [
          PathwayEligibilityRule(
            id: 'r1',
            programId: 'ca-study-permit',
            jurisdiction: 'CA',
            requiredFields: const {ImmigrationProfileField.nationality},
            evidence: PathwayRuleEvidence(
              jurisdiction: 'CA',
              title: 't',
              sourceUrl: 'https://www.canada.ca/x',
              retrievedAt: now,
            ),
          ),
        ],
      );
      expect(const CuratedRulesGate().loadApproved(package), isEmpty);
    });

    test('approved package exposes rules; recommendations stay gated', () {
      final rule = PathwayEligibilityRule(
        id: 'r1',
        programId: 'ca-study-permit',
        jurisdiction: 'CA',
        requiredFields: const {ImmigrationProfileField.nationality},
        evidence: PathwayRuleEvidence(
          jurisdiction: 'CA',
          title: 't',
          sourceUrl: 'https://www.canada.ca/x',
          retrievedAt: now,
        ),
      );
      final package = CuratedRulePackage(
        packageId: 'p1',
        editorialApproved: true,
        approvedAt: now,
        approverLabel: 'editorial-test',
        rules: [rule],
      );
      final rules = const CuratedRulesGate().loadApproved(package);
      expect(rules.length, 1);

      final report = const RecommendationEngine().recommend(
        profile: const ImmigrationProfile(nationality: 'IR'),
        candidateProgramIds: ['ca-study-permit'],
        rules: rules,
        now: now,
      );
      expect(report.included, isNotEmpty);
    });

    test(
      'evidence-linked package fails if registry not eligibility-approved',
      () {
        final snap = EvidenceRegistrySnapshot(
          version: 1,
          generatedAt: now,
          records: [
            EvidenceRecord(
              id: 'ev1',
              topicKey: 't',
              statement: 's',
              source: gov(),
              reviewStatus: EvidenceReviewStatus.pendingReview,
            ),
          ],
        );
        final package = CuratedRulePackage(
          packageId: 'p1',
          editorialApproved: true,
          approvedAt: now,
          evidenceRecordIds: const ['ev1'],
          rules: [
            PathwayEligibilityRule(
              id: 'r1',
              programId: 'ca-study-permit',
              jurisdiction: 'CA',
              requiredFields: const {ImmigrationProfileField.nationality},
              evidence: PathwayRuleEvidence(
                jurisdiction: 'CA',
                title: 't',
                sourceUrl: 'https://www.canada.ca/x',
                retrievedAt: now,
              ),
            ),
          ],
        );
        expect(
          const CuratedRulesGate().loadIfEvidenceSupports(
            package: package,
            registry: snap,
          ),
          isEmpty,
        );
      },
    );
  });
}
