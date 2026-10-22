import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../visa/domain/entities/canonical_pathway_entities.dart';
import '../../../visa/domain/entities/search_entities.dart';

@immutable
class AdminCmsArticleListItem {
  final String id;
  final String slug;
  final String locale;
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
    this.locale = 'fa',
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
      locale: json['locale'] as String,
      countryCode: (json['country_code'] ?? json['countryCode'] ?? '')
          .toString(),
      countryName: (json['country_name'] ?? json['countryName'] ?? '')
          .toString(),
      title: (json['title'] ?? '').toString(),
      articleType: SearchArticleType.fromString((json['kind'])?.toString()),
      factualStatus: FactualStatus.fromString(
        (json['verification_state'])?.toString(),
      ),
      editorialStatus: ArticleEditorialStatus.fromString(
        (json['editorial_state'])?.toString(),
      ),
      lastUpdated: DateTime.parse(json['updated_at'] as String),
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
        return 'تأیید پیش‌نویس؛ منتشر نشده';
      case SourceProposalReviewStatus.rejected:
        return 'رد شد';
    }
  }
}

@immutable
class AdminSourceChangeProposal {
  final String id;
  final int revision;
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
    this.revision = 1,
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
    final evidence = json['evidence'] as List;
    final source = evidence.isEmpty ? null : evidence.first as Map;
    final evidenceUrl = source?['url'] as String? ?? '';
    return AdminSourceChangeProposal(
      id: json['id'] as String,
      revision: json['revision'] as int,
      authorityName:
          source?['publisher'] as String? ?? json['authority_id'] as String,
      authorityDomain: Uri.tryParse(evidenceUrl)?.host ?? '',
      evidenceUrl: evidenceUrl,
      countryCode: (json['country_code'] ?? json['countryCode'] ?? '')
          .toString(),
      pathwaySlug: (json['pathway_slug'] ?? json['pathwaySlug'] ?? '')
          .toString(),
      detectedAt: DateTime.parse(json['created_at'] as String),
      factualStatus: FactualStatus.fromString(
        (json['verification_state'])?.toString(),
      ),
      reviewStatus: SourceProposalReviewStatus.fromString(
        (json['editorial_state'] == 'approved'
            ? 'approved'
            : json['editorial_state'] == 'rejected'
            ? 'rejected'
            : 'pending'),
      ),
      previousText: 'نسخه مبنا: ${json['base_revision']}',
      proposedText: const JsonEncoder.withIndent('  ').convert(json['changes']),
      summaryOfChanges:
          '${(json['changes'] as List).length} تغییر در بخش‌های مقاله',
      reviewerNotes:
          json['reviewer_notes']?.toString() ??
          json['reviewerNotes']?.toString(),
    );
  }
}
