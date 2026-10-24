import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../visa/domain/entities/canonical_pathway_entities.dart';
import '../../../visa/domain/entities/search_entities.dart';

export '../../../visa/domain/entities/canonical_pathway_entities.dart'
    show ArticleEditorialStatus;
export '../../../visa/domain/entities/search_entities.dart'
    show FactualStatus, SearchArticleType;

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
      locale: json['locale'] as String? ?? 'fa',
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
      case 'accept':
        return SourceProposalReviewStatus.approved;
      case 'rejected':
      case 'reject':
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
class ContentBlock {
  final String id;
  final String type; // 'paragraph', 'heading', 'bullet_list', 'numbered_list', 'callout'
  final String text;
  final List<String> items;

  const ContentBlock({
    required this.id,
    required this.type,
    required this.text,
    required this.items,
  });

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      id: json['id'] as String,
      type: json['type'] as String,
      text: json['text'] as String? ?? '',
      items: (json['items'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'text': text,
        'items': items,
      };
}

@immutable
class EvidenceInput {
  final String snapshotId;
  final String? claimId;
  final String excerpt;
  final String? locator;

  const EvidenceInput({
    required this.snapshotId,
    this.claimId,
    required this.excerpt,
    this.locator,
  });

  factory EvidenceInput.fromJson(Map<String, dynamic> json) {
    return EvidenceInput(
      snapshotId: json['snapshot_id'] as String,
      claimId: json['claim_id'] as String?,
      excerpt: json['excerpt'] as String,
      locator: json['locator'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'snapshot_id': snapshotId,
        'claim_id': claimId,
        'excerpt': excerpt,
        'locator': locator,
      };
}

@immutable
class ArticleSectionInput {
  final String id;
  final String anchor;
  final String heading;
  final int order;
  final List<ContentBlock> blocks;
  final List<EvidenceInput> evidenceRefs;

  const ArticleSectionInput({
    required this.id,
    required this.anchor,
    required this.heading,
    required this.order,
    required this.blocks,
    required this.evidenceRefs,
  });

  factory ArticleSectionInput.fromJson(Map<String, dynamic> json) {
    return ArticleSectionInput(
      id: json['id'] as String,
      anchor: json['anchor'] as String,
      heading: json['heading'] as String,
      order: json['order'] as int,
      blocks: (json['blocks'] as List?)
              ?.map((e) => ContentBlock.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      evidenceRefs: (json['evidence_refs'] as List?)
              ?.map((e) => EvidenceInput.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'anchor': anchor,
        'heading': heading,
        'order': order,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'evidence_refs': evidenceRefs.map((e) => e.toJson()).toList(),
      };
}

@immutable
class SectionChange {
  final String sectionId;
  final String operation; // 'replace', 'add', 'remove'
  final String? beforeHash;
  final ArticleSectionInput? replacement;
  final List<String> claimIds;

  const SectionChange({
    required this.sectionId,
    required this.operation,
    this.beforeHash,
    this.replacement,
    required this.claimIds,
  });

  factory SectionChange.fromJson(Map<String, dynamic> json) {
    return SectionChange(
      sectionId: json['section_id'] as String,
      operation: json['operation'] as String,
      beforeHash: json['before_hash'] as String?,
      replacement: json['replacement'] != null
          ? ArticleSectionInput.fromJson(
              Map<String, dynamic>.from(json['replacement'] as Map),
            )
          : null,
      claimIds: (json['claim_ids'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'section_id': sectionId,
        'operation': operation,
        'before_hash': beforeHash,
        'replacement': replacement?.toJson(),
        'claim_ids': claimIds,
      };
}

@immutable
class EvidenceRef {
  final String sourceDocumentId;
  final String snapshotId;
  final String? claimId;
  final String? sectionId;
  final String url;
  final String publisher;
  final String sourceClass; // 'radvisa', 'digivisa', 'radmohajer', 'official_primary', 'other'
  final String? authorityId;
  final String excerpt;
  final String? locator;
  final DateTime fetchedAt;
  final DateTime? verifiedAt;
  final DateTime? freshUntil;
  final FactualStatus verificationState;
  final String freshnessState; // 'live', 'cached', 'revalidating', 'stale'

  const EvidenceRef({
    required this.sourceDocumentId,
    required this.snapshotId,
    this.claimId,
    this.sectionId,
    required this.url,
    required this.publisher,
    required this.sourceClass,
    this.authorityId,
    required this.excerpt,
    this.locator,
    required this.fetchedAt,
    this.verifiedAt,
    this.freshUntil,
    required this.verificationState,
    required this.freshnessState,
  });

  factory EvidenceRef.fromJson(Map<String, dynamic> json) {
    return EvidenceRef(
      sourceDocumentId: json['source_document_id'] as String,
      snapshotId: json['snapshot_id'] as String,
      claimId: json['claim_id'] as String?,
      sectionId: json['section_id'] as String?,
      url: json['url'] as String,
      publisher: json['publisher'] as String,
      sourceClass: json['source_class'] as String,
      authorityId: json['authority_id'] as String?,
      excerpt: json['excerpt'] as String,
      locator: json['locator'] as String?,
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'] as String)
          : null,
      freshUntil: json['fresh_until'] != null
          ? DateTime.tryParse(json['fresh_until'] as String)
          : null,
      verificationState: FactualStatus.fromString(
        json['verification_state'] as String?,
      ),
      freshnessState: json['freshness_state'] as String? ?? 'live',
    );
  }

  Map<String, dynamic> toJson() => {
        'source_document_id': sourceDocumentId,
        'snapshot_id': snapshotId,
        'claim_id': claimId,
        'section_id': sectionId,
        'url': url,
        'publisher': publisher,
        'source_class': sourceClass,
        'authority_id': authorityId,
        'excerpt': excerpt,
        'locator': locator,
        'fetched_at': fetchedAt.toIso8601String(),
        'verified_at': verifiedAt?.toIso8601String(),
        'fresh_until': freshUntil?.toIso8601String(),
        'verification_state': verificationState.name,
        'freshness_state': freshnessState,
      };
}

@immutable
class AdminSourceChangeProposal {
  final String id;
  final int revision;
  final String targetArticleId;
  final int baseRevision;
  final String? oldSnapshotId;
  final String newSnapshotId;
  final String authorityId;
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
  final List<SectionChange> changes;
  final List<EvidenceRef> evidence;

  const AdminSourceChangeProposal({
    required this.id,
    this.revision = 1,
    this.targetArticleId = '',
    this.baseRevision = 1,
    this.oldSnapshotId,
    this.newSnapshotId = '',
    this.authorityId = '',
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
    this.changes = const [],
    this.evidence = const [],
  });

  factory AdminSourceChangeProposal.fromJson(Map<String, dynamic> json) {
    final rawEvidence = (json['evidence'] as List?) ?? const [];
    final evidenceList = <EvidenceRef>[];
    for (final e in rawEvidence) {
      if (e is Map<String, dynamic>) {
        try {
          evidenceList.add(EvidenceRef.fromJson(e));
        } catch (_) {}
      } else if (e is Map) {
        try {
          evidenceList.add(
            EvidenceRef.fromJson(Map<String, dynamic>.from(e)),
          );
        } catch (_) {}
      }
    }

    final rawChanges = (json['changes'] as List?) ?? const [];
    final changeList = <SectionChange>[];
    for (final c in rawChanges) {
      if (c is Map<String, dynamic>) {
        try {
          changeList.add(SectionChange.fromJson(c));
        } catch (_) {}
      } else if (c is Map) {
        try {
          changeList.add(
            SectionChange.fromJson(Map<String, dynamic>.from(c)),
          );
        } catch (_) {}
      }
    }

    final firstEvMap = rawEvidence.isNotEmpty && rawEvidence.first is Map
        ? rawEvidence.first as Map
        : null;
    final evidenceUrl = firstEvMap?['url'] as String? ?? '';
    final publisher = firstEvMap?['publisher'] as String? ??
        (json['authority_id'] as String? ?? '');

    return AdminSourceChangeProposal(
      id: json['id'] as String,
      revision: json['revision'] as int? ?? 1,
      targetArticleId: json['target_article_id'] as String? ?? '',
      baseRevision: json['base_revision'] as int? ?? 1,
      oldSnapshotId: json['old_snapshot_id'] as String?,
      newSnapshotId: json['new_snapshot_id'] as String? ?? '',
      authorityId: json['authority_id'] as String? ?? '',
      authorityName: publisher,
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
      proposedText: const JsonEncoder.withIndent('  ').convert(json['changes'] ?? []),
      summaryOfChanges:
          '${(json['changes'] as List?)?.length ?? 0} تغییر در بخش‌های مقاله',
      reviewerNotes: json['reviewer_notes']?.toString() ??
          json['reviewerNotes']?.toString(),
      changes: changeList,
      evidence: evidenceList,
    );
  }
}

@immutable
class ArticleRevisionResult {
  final String articleId;
  final String revisionId;
  final int revision;
  final String contentHash;
  final ArticleEditorialStatus editorialState;
  final FactualStatus verificationState;
  final DateTime updatedAt;

  const ArticleRevisionResult({
    required this.articleId,
    required this.revisionId,
    required this.revision,
    required this.contentHash,
    required this.editorialState,
    required this.verificationState,
    required this.updatedAt,
  });

  factory ArticleRevisionResult.fromJson(Map<String, dynamic> json) {
    return ArticleRevisionResult(
      articleId: json['article_id'] as String,
      revisionId: json['revision_id'] as String,
      revision: json['revision'] as int,
      contentHash: json['content_hash'] as String,
      editorialState: ArticleEditorialStatus.fromString(
        json['editorial_state'] as String?,
      ),
      verificationState: FactualStatus.fromString(
        json['verification_state'] as String?,
      ),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

@immutable
class PublicationResult {
  final String resourceId;
  final String revisionId;
  final int revision;
  final String eventId;
  final DateTime publishedAt;
  final Map<String, dynamic> target;

  const PublicationResult({
    required this.resourceId,
    required this.revisionId,
    required this.revision,
    required this.eventId,
    required this.publishedAt,
    required this.target,
  });

  factory PublicationResult.fromJson(Map<String, dynamic> json) {
    return PublicationResult(
      resourceId: json['resource_id'] as String,
      revisionId: json['revision_id'] as String,
      revision: json['revision'] as int,
      eventId: json['event_id'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
      target: (json['target'] is Map)
          ? Map<String, dynamic>.from(json['target'] as Map)
          : const {},
    );
  }
}

@immutable
class RevisionSummary {
  final String revisionId;
  final int revision;
  final String locale;
  final String contentHash;
  final ArticleEditorialStatus editorialState;
  final FactualStatus verificationState;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reason;

  const RevisionSummary({
    required this.revisionId,
    required this.revision,
    required this.locale,
    required this.contentHash,
    required this.editorialState,
    required this.verificationState,
    required this.createdAt,
    this.createdBy,
    this.reviewedAt,
    this.reviewedBy,
    this.reason,
  });

  factory RevisionSummary.fromJson(Map<String, dynamic> json) {
    return RevisionSummary(
      revisionId: json['revision_id'] as String,
      revision: json['revision'] as int,
      locale: json['locale'] as String,
      contentHash: json['content_hash'] as String,
      editorialState: ArticleEditorialStatus.fromString(
        json['editorial_state'] as String?,
      ),
      verificationState: FactualStatus.fromString(
        json['verification_state'] as String?,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      reviewedBy: json['reviewed_by'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

@immutable
class Authority {
  final String id;
  final String name;
  final String authorityType;
  final String? countryCode;
  final String jurisdiction;
  final List<String> competenceTopics;
  final List<String> officialDomains;
  final String verificationState; // 'unverified', 'verified', 'provisional', 'expired', 'blacklisted'
  final int verificationRevision;
  final DateTime? verifiedAt;
  final DateTime? expiresAt;

  const Authority({
    required this.id,
    required this.name,
    required this.authorityType,
    this.countryCode,
    required this.jurisdiction,
    required this.competenceTopics,
    required this.officialDomains,
    required this.verificationState,
    required this.verificationRevision,
    this.verifiedAt,
    this.expiresAt,
  });

  factory Authority.fromJson(Map<String, dynamic> json) {
    return Authority(
      id: json['id'] as String,
      name: json['name'] as String,
      authorityType: json['authority_type'] as String,
      countryCode: json['country_code'] as String?,
      jurisdiction: json['jurisdiction'] as String,
      competenceTopics: (json['competence_topics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      officialDomains: (json['official_domains'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      verificationState: json['verification_state'] as String? ?? 'unverified',
      verificationRevision: json['verification_revision'] as int? ?? 1,
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }

  bool get isVerified => verificationState == 'verified';
  bool get isExpired =>
      verificationState == 'expired' ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));
}
