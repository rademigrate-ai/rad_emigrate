import 'package:flutter/foundation.dart';

import '../../../visa/domain/entities/canonical_pathway_entities.dart';
import '../../../visa/domain/entities/search_entities.dart';

@immutable
class AdminCmsArticleListItem {
  final String id;
  final String slug;
  final String countryCode;
  final String countryName;
  final String title;
  final SearchArticleType articleType;
  final FactualStatus factualStatus;
  final ArticleEditorialStatus editorialStatus;
  final DateTime lastUpdated;
  final String authorityDomain;

  const AdminCmsArticleListItem({
    required this.id,
    required this.slug,
    required this.countryCode,
    required this.countryName,
    required this.title,
    required this.articleType,
    required this.factualStatus,
    required this.editorialStatus,
    required this.lastUpdated,
    required this.authorityDomain,
  });

  factory AdminCmsArticleListItem.fromJson(Map<String, dynamic> json) {
    return AdminCmsArticleListItem(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      countryCode: (json['country_code'] ?? json['countryCode'] ?? '')
          .toString(),
      countryName: (json['country_name'] ?? json['countryName'] ?? '')
          .toString(),
      title: (json['title'] ?? '').toString(),
      articleType: SearchArticleType.fromString(
        (json['article_type'] ?? json['articleType'])?.toString(),
      ),
      factualStatus: FactualStatus.fromString(
        (json['factual_status'] ?? json['factualStatus'])?.toString(),
      ),
      editorialStatus: ArticleEditorialStatus.fromString(
        (json['editorial_status'] ?? json['editorialStatus'])?.toString(),
      ),
      lastUpdated:
          DateTime.tryParse(json['last_updated']?.toString() ?? '') ??
          DateTime.now(),
      authorityDomain:
          (json['authority_domain'] ?? json['authorityDomain'] ?? '')
              .toString(),
    );
  }
}

enum SourceProposalReviewStatus {
  pending,
  approved,
  rejected;

  static SourceProposalReviewStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'approved':
        return SourceProposalReviewStatus.approved;
      case 'rejected':
        return SourceProposalReviewStatus.rejected;
      case 'pending':
      default:
        return SourceProposalReviewStatus.pending;
    }
  }

  String toDisplayPersian() {
    switch (this) {
      case SourceProposalReviewStatus.pending:
        return 'در انتظار بررسی';
      case SourceProposalReviewStatus.approved:
        return 'تأیید و ادغام شد';
      case SourceProposalReviewStatus.rejected:
        return 'رد شد';
    }
  }
}

@immutable
class AdminSourceChangeProposal {
  final String id;
  final String authorityName;
  final String authorityDomain;
  final String evidenceUrl;
  final String countryCode;
  final String pathwaySlug;
  final DateTime detectedAt;
  final FactualStatus factualStatus;
  final SourceProposalReviewStatus reviewStatus;
  final String previousText;
  final String proposedText;
  final String summaryOfChanges;
  final String? reviewerNotes;

  const AdminSourceChangeProposal({
    required this.id,
    required this.authorityName,
    required this.authorityDomain,
    required this.evidenceUrl,
    required this.countryCode,
    required this.pathwaySlug,
    required this.detectedAt,
    required this.factualStatus,
    required this.reviewStatus,
    required this.previousText,
    required this.proposedText,
    required this.summaryOfChanges,
    this.reviewerNotes,
  });

  factory AdminSourceChangeProposal.fromJson(Map<String, dynamic> json) {
    return AdminSourceChangeProposal(
      id: (json['id'] ?? '').toString(),
      authorityName: (json['authority_name'] ?? json['authorityName'] ?? '')
          .toString(),
      authorityDomain:
          (json['authority_domain'] ?? json['authorityDomain'] ?? '')
              .toString(),
      evidenceUrl: (json['evidence_url'] ?? json['evidenceUrl'] ?? '')
          .toString(),
      countryCode: (json['country_code'] ?? json['countryCode'] ?? '')
          .toString(),
      pathwaySlug: (json['pathway_slug'] ?? json['pathwaySlug'] ?? '')
          .toString(),
      detectedAt:
          DateTime.tryParse(json['detected_at']?.toString() ?? '') ??
          DateTime.now(),
      factualStatus: FactualStatus.fromString(
        (json['factual_status'] ?? json['factualStatus'])?.toString(),
      ),
      reviewStatus: SourceProposalReviewStatus.fromString(
        (json['review_status'] ?? json['reviewStatus'])?.toString(),
      ),
      previousText: (json['previous_text'] ?? json['previousText'] ?? '')
          .toString(),
      proposedText: (json['proposed_text'] ?? json['proposedText'] ?? '')
          .toString(),
      summaryOfChanges:
          (json['summary_of_changes'] ?? json['summaryOfChanges'] ?? '')
              .toString(),
      reviewerNotes:
          json['reviewer_notes']?.toString() ??
          json['reviewerNotes']?.toString(),
    );
  }
}
