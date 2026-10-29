import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/domain/entities/admin_cms_entities.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/full_page_comparison_viewer.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/source_provenance_badge.dart';

void main() {
  test('source class alone never constitutes official verification', () {
    expect(
      SourceTrustLevel.fromString('official_primary'),
      isNot(SourceTrustLevel.officiallyVerified),
    );
    expect(
      SourceTrustLevel.fromString('official'),
      isNot(SourceTrustLevel.officiallyVerified),
    );
  });
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('complete review and all citations fit width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final base = ArticleSectionInput(
        id: 'section',
        anchor: 'test',
        heading: 'Synthetic baseline',
        order: 0,
        blocks: [
          ContentBlock(
            id: 'block',
            type: 'paragraph',
            text: 'Synthetic original paragraph.',
            items: const [],
          ),
        ],
        evidenceRefs: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FullPageComparisonViewer(
                articleTitle: 'Synthetic review; no legal claims',
                baseRevision: 1,
                proposedRevision: 2,
                baseSections: [base],
                changes: [
                  SectionChange(
                    sectionId: 'section',
                    operation: 'replace',
                    beforeHash: 'hash',
                    replacement: base,
                    claimIds: const [],
                  ),
                ],
                evidence: [
                  for (var i = 0; i < 2; i++)
                    EvidenceRef(
                      sourceDocumentId: 'doc$i',
                      snapshotId: 'snapshot$i',
                      sectionId: 'section',
                      url: 'https://example.org/source$i',
                      publisher: 'Synthetic source $i',
                      sourceClass: 'official_primary',
                      excerpt: 'Synthetic evidence $i',
                      fetchedAt: DateTime(2026),
                      verificationState: FactualStatus.unverified,
                      freshnessState: 'unknown',
                    ),
                ],
                sectionEdits: const {'section': 'Synthetic reviewer edit.'},
                isPersian: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Synthetic reviewer edit.'), findsOneWidget);
      expect(find.textContaining('Synthetic source 0'), findsOneWidget);
      expect(find.textContaining('Synthetic source 1'), findsOneWidget);
      expect(find.textContaining('Approved'), findsNothing);
      final badges = tester.widgetList<SourceProvenanceBadge>(
        find.byType(SourceProvenanceBadge),
      );
      expect(
        badges.every(
          (b) => b.trustLevel != SourceTrustLevel.officiallyVerified,
        ),
        isTrue,
      );
    });
  }
}
