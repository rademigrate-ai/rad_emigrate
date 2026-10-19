import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/admin/data/admin_cms_repository.dart';
import 'package:rad_emigrate/features/admin/domain/entities/admin_cms_entities.dart';
import 'package:rad_emigrate/features/visa/domain/entities/search_entities.dart';

void main() {
  group('Admin CMS & Source Proposal Tests', () {
    test(
      'AdminSourceChangeProposal correctly parses model and review status',
      () {
        final proposal = AdminSourceChangeProposal(
          id: 'prop-1',
          authorityName: 'Make it in Germany',
          authorityDomain: 'make-it-in-germany.com',
          evidenceUrl: 'https://make-it-in-germany.com',
          countryCode: 'de',
          pathwaySlug: 'chancenkarte',
          detectedAt: DateTime.now(),
          factualStatus: FactualStatus.verified,
          reviewStatus: SourceProposalReviewStatus.pending,
          previousText: 'Old text',
          proposedText: 'New text',
          summaryOfChanges: 'Updated amount',
        );

        expect(proposal.authorityDomain, 'make-it-in-germany.com');
        expect(proposal.reviewStatus, SourceProposalReviewStatus.pending);
        expect(proposal.reviewStatus.toDisplayPersian(), 'در انتظار بررسی');
      },
    );

    test('AdminCmsRepository returns article list and proposals', () async {
      final repo = SupabaseAdminCmsRepository(SupabaseClientService.instance);
      final articles = await repo.listCmsArticles();
      expect(articles.isNotEmpty, isTrue);

      final proposals = await repo.listProposals();
      expect(proposals.isNotEmpty, isTrue);
      expect(proposals.first.previousText.isNotEmpty, isTrue);
      expect(proposals.first.proposedText.isNotEmpty, isTrue);

      final detail = await repo.getProposalDetail(proposals.first.id);
      expect(detail, isNotNull);
      expect(detail!.id, proposals.first.id);
    });

    test(
      'AdminCmsRepository allows approving or rejecting proposals',
      () async {
        final repo = SupabaseAdminCmsRepository(SupabaseClientService.instance);
        final okApprove = await repo.reviewProposal(
          proposalId: 'prop-de-001',
          decision: SourceProposalReviewStatus.approved,
          factualStatus: FactualStatus.verified,
          reviewerNotes: 'تأیید بر اساس وب‌سایت رسمی فدرال',
        );
        expect(okApprove, isTrue);

        final okReject = await repo.reviewProposal(
          proposalId: 'prop-ca-002',
          decision: SourceProposalReviewStatus.rejected,
          factualStatus: FactualStatus.incorrect,
          reviewerNotes: 'مغایرت محرز نیست',
        );
        expect(okReject, isTrue);
      },
    );
  });
}
