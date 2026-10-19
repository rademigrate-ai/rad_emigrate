import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/knowledge/domain/knowledge_integrity.dart';

void main() {
  final now = DateTime.utc(2026, 10, 18);

  KnowledgeSourceIdentity govSource({
    String id = 'gov1',
    String url = 'https://www.canada.ca/immigration',
    DateTime? retrievedAt,
    String? version,
    String? hash,
    SourceAuthorityClass authority = SourceAuthorityClass.government,
  }) {
    return KnowledgeSourceIdentity(
      id: id,
      title: 'IRCC',
      canonicalUrl: url,
      authority: authority,
      retrievedAt: retrievedAt ?? now.subtract(const Duration(days: 10)),
      jurisdiction: 'CA',
      programIds: const ['ca-express'],
      versionLabel: version,
      contentHash: hash,
    );
  }

  group('canonicalizeUrl', () {
    test('strips trailing slash and lowercases host', () {
      expect(
        KnowledgeIntegrityService.canonicalizeUrl(
          'https://WWW.Canada.CA/immigration/',
        ),
        'https://www.canada.ca/immigration',
      );
    });
  });

  group('invalidSourceReasons', () {
    test('missing fields flagged', () {
      final bad = KnowledgeSourceIdentity(
        id: '',
        title: '',
        canonicalUrl: 'not a url',
        authority: SourceAuthorityClass.unverified,
        retrievedAt: now,
      );
      final reasons = KnowledgeIntegrityService.invalidSourceReasons(bad);
      expect(
        reasons,
        containsAll(['missing_id', 'missing_title', 'invalid_url']),
      );
    });

    test('valid government source has no reasons', () {
      final reasons = KnowledgeIntegrityService.invalidSourceReasons(
        govSource(),
      );
      expect(reasons, isEmpty);
    });
  });

  group('duplicates', () {
    test('duplicate ids detected', () {
      final dups = KnowledgeIntegrityService.findDuplicateSourceIds([
        govSource(id: 'gov1'),
        govSource(id: 'gov1', url: 'https://www.canada.ca/other'),
      ]);
      expect(dups, contains('gov1'));
    });

    test('duplicate canonical urls detected', () {
      final dups = KnowledgeIntegrityService.findDuplicateSourceIds([
        govSource(id: 'a', url: 'https://example.com/path/'),
        govSource(id: 'b', url: 'https://example.com/path'),
      ]);
      expect(dups, contains('b'));
    });
  });

  group('conflicts', () {
    test('divergent claims on same topic conflict', () {
      final claims = [
        const KnowledgeClaim(
          id: 'c1',
          topicKey: 'processing_time',
          statement: 'Up to 8 weeks',
          sourceId: 'gov1',
        ),
        const KnowledgeClaim(
          id: 'c2',
          topicKey: 'processing_time',
          statement: 'Up to 12 weeks',
          sourceId: 'gov2',
        ),
      ];
      final conflicts = KnowledgeIntegrityService.detectConflicts(claims);
      expect(conflicts.length, 1);
      expect(conflicts.first.requiresHumanReview, isTrue);
    });

    test('identical statements do not conflict', () {
      final claims = [
        const KnowledgeClaim(
          id: 'c1',
          topicKey: 'fee',
          statement: '100 CAD',
          sourceId: 'gov1',
        ),
        const KnowledgeClaim(
          id: 'c2',
          topicKey: 'fee',
          statement: '100 CAD',
          sourceId: 'gov2',
        ),
      ];
      expect(KnowledgeIntegrityService.detectConflicts(claims), isEmpty);
    });
  });

  group('version compare', () {
    test('hash change detected', () {
      final prev = govSource(version: 'v1', hash: 'aaa');
      final curr = govSource(version: 'v2', hash: 'bbb');
      final change = KnowledgeIntegrityService.compareVersions(
        previous: prev,
        current: curr,
      );
      expect(change.changed, isTrue);
    });
  });

  group('evaluate report', () {
    test('AI-only topic flagged for human review', () {
      final sources = [
        govSource(id: 'ai1', authority: SourceAuthorityClass.aiGenerated),
      ];
      final claims = [
        const KnowledgeClaim(
          id: 'c1',
          topicKey: 'eligibility',
          statement: 'You will be approved',
          sourceId: 'ai1',
        ),
      ];
      final report = const KnowledgeIntegrityService().evaluate(
        sources: sources,
        claims: claims,
        now: now,
      );
      expect(report.aiOnlyTopics, contains('eligibility'));
      expect(report.requiresHumanReview, isTrue);
      expect(report.hasInsufficientEvidence, isTrue);
    });

    test('authoritative claim is sufficient evidence', () {
      final sources = [govSource()];
      final claims = [
        const KnowledgeClaim(
          id: 'c1',
          topicKey: 'fee',
          statement: 'CAD 150',
          sourceId: 'gov1',
        ),
      ];
      final report = const KnowledgeIntegrityService().evaluate(
        sources: sources,
        claims: claims,
        now: now,
      );
      expect(report.hasInsufficientEvidence, isFalse);
      expect(report.conflicts, isEmpty);
    });

    test('expired authoritative evidence flagged', () {
      final sources = [
        govSource(retrievedAt: now.subtract(const Duration(days: 400))),
      ];
      final claims = [
        const KnowledgeClaim(
          id: 'c1',
          topicKey: 'fee',
          statement: 'CAD 150',
          sourceId: 'gov1',
        ),
      ];
      final report = const KnowledgeIntegrityService().evaluate(
        sources: sources,
        claims: claims,
        now: now,
      );
      expect(report.hasExpiredAuthoritativeEvidence, isTrue);
      expect(report.requiresHumanReview, isTrue);
    });

    test('jurisdiction applicability', () {
      final s = govSource();
      expect(s.appliesToJurisdiction('CA'), isTrue);
      expect(s.appliesToJurisdiction('US'), isFalse);
      expect(s.appliesToProgram('ca-express'), isTrue);
      expect(s.appliesToProgram('other'), isFalse);
    });
  });
}
