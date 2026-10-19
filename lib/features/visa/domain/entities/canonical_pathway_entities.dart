import 'package:flutter/foundation.dart';

import 'search_entities.dart';

/// Editorial lifecycle status (distinct from factual truth status).
enum ArticleEditorialStatus {
  draft,
  inReview,
  approved,
  published,
  archived;

  static ArticleEditorialStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'in_review':
        return ArticleEditorialStatus.inReview;
      case 'approved':
        return ArticleEditorialStatus.approved;
      case 'published':
        return ArticleEditorialStatus.published;
      case 'archived':
        return ArticleEditorialStatus.archived;
      case 'draft':
      default:
        return ArticleEditorialStatus.draft;
    }
  }

  String toDisplayPersian() {
    switch (this) {
      case ArticleEditorialStatus.draft:
        return 'پیش‌نویس';
      case ArticleEditorialStatus.inReview:
        return 'در حال بررسی سردبیری';
      case ArticleEditorialStatus.approved:
        return 'تأیید سردبیری';
      case ArticleEditorialStatus.published:
        return 'منتشرشده';
      case ArticleEditorialStatus.archived:
        return 'بایگانی‌شده';
    }
  }
}

/// Official source evidence attribution.
@immutable
class OfficialSourceAttribution {
  final String authorityName;
  final String authorityDomain;
  final String originalEvidenceUrl;
  final DateTime lastFactCheckedAt;
  final FactualStatus factualStatus;

  const OfficialSourceAttribution({
    required this.authorityName,
    required this.authorityDomain,
    required this.originalEvidenceUrl,
    required this.lastFactCheckedAt,
    required this.factualStatus,
  });

  factory OfficialSourceAttribution.fromJson(Map<String, dynamic> json) {
    return OfficialSourceAttribution(
      authorityName: (json['authority_name'] ?? json['authorityName'] ?? '')
          .toString(),
      authorityDomain:
          (json['authority_domain'] ?? json['authorityDomain'] ?? '')
              .toString(),
      originalEvidenceUrl:
          (json['original_evidence_url'] ?? json['originalEvidenceUrl'] ?? '')
              .toString(),
      lastFactCheckedAt:
          DateTime.tryParse(json['last_fact_checked_at']?.toString() ?? '') ??
          DateTime.now(),
      factualStatus: FactualStatus.fromString(
        (json['factual_status'] ?? json['factualStatus'])?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'authority_name': authorityName,
    'authority_domain': authorityDomain,
    'original_evidence_url': originalEvidenceUrl,
    'last_fact_checked_at': lastFactCheckedAt.toIso8601String(),
    'factual_status': factualStatus.name,
  };
}

/// Sub-section in a canonical pathway article.
@immutable
class PathwaySection {
  final String id;
  final String anchor;
  final String title;
  final String bodyMarkdown;
  final int displayOrder;

  const PathwaySection({
    required this.id,
    required this.anchor,
    required this.title,
    required this.bodyMarkdown,
    required this.displayOrder,
  });

  factory PathwaySection.fromJson(Map<String, dynamic> json) {
    return PathwaySection(
      id: (json['id'] ?? '').toString(),
      anchor: (json['anchor'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      bodyMarkdown: (json['body_markdown'] ?? json['bodyMarkdown'] ?? '')
          .toString(),
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Eligibility requirements block.
@immutable
class PathwayEligibility {
  final String? minimumEducation;
  final String? languageProficiency;
  final int? workExperienceYears;
  final int? ageLimitMax;
  final int? pointSystemPassMark;
  final List<String> additionalRules;

  const PathwayEligibility({
    this.minimumEducation,
    this.languageProficiency,
    this.workExperienceYears,
    this.ageLimitMax,
    this.pointSystemPassMark,
    this.additionalRules = const [],
  });

  factory PathwayEligibility.fromJson(Map<String, dynamic> json) {
    final rules =
        (json['additional_rules'] as List? ??
                json['additionalRules'] as List? ??
                [])
            .map((e) => e.toString())
            .toList();
    return PathwayEligibility(
      minimumEducation:
          json['minimum_education']?.toString() ??
          json['minimumEducation']?.toString(),
      languageProficiency:
          json['language_proficiency']?.toString() ??
          json['languageProficiency']?.toString(),
      workExperienceYears:
          (json['work_experience_years'] as num?)?.toInt() ??
          (json['workExperienceYears'] as num?)?.toInt(),
      ageLimitMax:
          (json['age_limit_max'] as num?)?.toInt() ??
          (json['ageLimitMax'] as num?)?.toInt(),
      pointSystemPassMark:
          (json['point_system_pass_mark'] as num?)?.toInt() ??
          (json['pointSystemPassMark'] as num?)?.toInt(),
      additionalRules: rules,
    );
  }
}

/// Individual item in financial costs.
@immutable
class PathwayFinancialCostItem {
  final String label;
  final double amount;
  final String currency;
  final bool isRefundable;
  final String? description;

  const PathwayFinancialCostItem({
    required this.label,
    required this.amount,
    required this.currency,
    this.isRefundable = false,
    this.description,
  });

  factory PathwayFinancialCostItem.fromJson(Map<String, dynamic> json) {
    return PathwayFinancialCostItem(
      label: (json['label'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] ?? 'EUR').toString().toUpperCase(),
      isRefundable:
          json['is_refundable'] as bool? ??
          json['isRefundable'] as bool? ??
          false,
      description: json['description']?.toString(),
    );
  }
}

/// Process step with timeline and authority action.
@immutable
class PathwayProcessStep {
  final int stepNumber;
  final String title;
  final String description;
  final int? estimatedWeeks;
  final String? authorityAction;

  const PathwayProcessStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.estimatedWeeks,
    this.authorityAction,
  });

  factory PathwayProcessStep.fromJson(Map<String, dynamic> json) {
    return PathwayProcessStep(
      stepNumber:
          (json['step_number'] as num?)?.toInt() ??
          (json['stepNumber'] as num?)?.toInt() ??
          1,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      estimatedWeeks:
          (json['estimated_weeks'] as num?)?.toInt() ??
          (json['estimatedWeeks'] as num?)?.toInt(),
      authorityAction:
          json['authority_action']?.toString() ??
          json['authorityAction']?.toString(),
    );
  }
}

/// Summary reference to an independent article («عناوین دیگر»).
@immutable
class IndependentArticleSummary {
  final String id;
  final String slug;
  final String title;
  final String countryCode;
  final String summary;
  final int readingTimeMinutes;
  final String category;

  const IndependentArticleSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.countryCode,
    required this.summary,
    required this.readingTimeMinutes,
    required this.category,
  });

  factory IndependentArticleSummary.fromJson(Map<String, dynamic> json) {
    return IndependentArticleSummary(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      countryCode: (json['country_code'] ?? json['countryCode'] ?? '')
          .toString(),
      summary: (json['summary'] ?? '').toString(),
      readingTimeMinutes: (json['reading_time_minutes'] as num?)?.toInt() ?? 5,
      category: (json['category'] ?? '').toString(),
    );
  }
}

/// Canonical merged pathway article (Country × Pathway).
@immutable
class CanonicalPathwayArticle {
  final String id;
  final String slug;
  final String countryCode;
  final String countryName;
  final String countryFlag;
  final String pathwayTitle;
  final String category;
  final FactualStatus factualStatus;
  final ArticleEditorialStatus editorialStatus;
  final String summary;
  final List<OfficialSourceAttribution> officialSources;
  final List<PathwaySection> sections;
  final PathwayEligibility? eligibility;
  final List<PathwayFinancialCostItem> costs;
  final List<PathwayProcessStep> steps;
  final List<String> requiredDocuments;
  final List<Map<String, String>> faqItems;
  final List<IndependentArticleSummary> relatedArticles;
  final DateTime lastFactCheckedAt;

  const CanonicalPathwayArticle({
    required this.id,
    required this.slug,
    required this.countryCode,
    required this.countryName,
    required this.countryFlag,
    required this.pathwayTitle,
    required this.category,
    required this.factualStatus,
    required this.editorialStatus,
    required this.summary,
    required this.officialSources,
    required this.sections,
    this.eligibility,
    required this.costs,
    required this.steps,
    required this.requiredDocuments,
    required this.faqItems,
    required this.relatedArticles,
    required this.lastFactCheckedAt,
  });

  factory CanonicalPathwayArticle.fromJson(Map<String, dynamic> json) {
    final rawSources =
        json['official_sources'] as List? ??
        json['officialSources'] as List? ??
        [];
    final sources = rawSources
        .whereType<Map<String, dynamic>>()
        .map((s) => OfficialSourceAttribution.fromJson(s))
        .toList();

    final rawSections = json['sections'] as List? ?? [];
    final sections = rawSections
        .whereType<Map<String, dynamic>>()
        .map((s) => PathwaySection.fromJson(s))
        .toList();

    final rawCosts = json['costs'] as List? ?? [];
    final costs = rawCosts
        .whereType<Map<String, dynamic>>()
        .map((c) => PathwayFinancialCostItem.fromJson(c))
        .toList();

    final rawSteps = json['steps'] as List? ?? [];
    final steps = rawSteps
        .whereType<Map<String, dynamic>>()
        .map((st) => PathwayProcessStep.fromJson(st))
        .toList();

    final rawDocs =
        (json['required_documents'] as List? ??
                json['requiredDocuments'] as List? ??
                [])
            .map((d) => d.toString())
            .toList();

    final rawFaq =
        (json['faq_items'] as List? ?? json['faqItems'] as List? ?? [])
            .map((f) => Map<String, String>.from(f as Map))
            .toList();

    final rawRelated =
        json['related_articles'] as List? ??
        json['relatedArticles'] as List? ??
        [];
    final related = rawRelated
        .whereType<Map<String, dynamic>>()
        .map((r) => IndependentArticleSummary.fromJson(r))
        .toList();

    final eligRaw = json['eligibility'] as Map<String, dynamic>?;

    return CanonicalPathwayArticle(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      countryCode: (json['country_code'] ?? json['countryCode'] ?? '')
          .toString(),
      countryName: (json['country_name'] ?? json['countryName'] ?? '')
          .toString(),
      countryFlag: (json['country_flag'] ?? json['countryFlag'] ?? '🌍')
          .toString(),
      pathwayTitle: (json['pathway_title'] ?? json['pathwayTitle'] ?? '')
          .toString(),
      category: (json['category'] ?? '').toString(),
      factualStatus: FactualStatus.fromString(
        (json['factual_status'] ?? json['factualStatus'])?.toString(),
      ),
      editorialStatus: ArticleEditorialStatus.fromString(
        (json['editorial_status'] ?? json['editorialStatus'])?.toString(),
      ),
      summary: (json['summary'] ?? '').toString(),
      officialSources: sources,
      sections: sections,
      eligibility: eligRaw != null
          ? PathwayEligibility.fromJson(eligRaw)
          : null,
      costs: costs,
      steps: steps,
      requiredDocuments: rawDocs,
      faqItems: rawFaq,
      relatedArticles: related,
      lastFactCheckedAt:
          DateTime.tryParse(json['last_fact_checked_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// Independent specialized article («عناوین دیگر»).
@immutable
class IndependentArticle {
  final String id;
  final String slug;
  final String countryCode;
  final String countryName;
  final String title;
  final String summary;
  final String bodyMarkdown;
  final String category;
  final FactualStatus factualStatus;
  final ArticleEditorialStatus editorialStatus;
  final int readingTimeMinutes;
  final DateTime publishedAt;
  final List<OfficialSourceAttribution> officialSources;
  final String? canonicalPathwaySlug;

  const IndependentArticle({
    required this.id,
    required this.slug,
    required this.countryCode,
    required this.countryName,
    required this.title,
    required this.summary,
    required this.bodyMarkdown,
    required this.category,
    required this.factualStatus,
    required this.editorialStatus,
    required this.readingTimeMinutes,
    required this.publishedAt,
    required this.officialSources,
    this.canonicalPathwaySlug,
  });

  factory IndependentArticle.fromJson(Map<String, dynamic> json) {
    final rawSources =
        json['official_sources'] as List? ??
        json['officialSources'] as List? ??
        [];
    final sources = rawSources
        .whereType<Map<String, dynamic>>()
        .map((s) => OfficialSourceAttribution.fromJson(s))
        .toList();

    return IndependentArticle(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      countryCode: (json['country_code'] ?? json['countryCode'] ?? '')
          .toString(),
      countryName: (json['country_name'] ?? json['countryName'] ?? '')
          .toString(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      bodyMarkdown: (json['body_markdown'] ?? json['bodyMarkdown'] ?? '')
          .toString(),
      category: (json['category'] ?? '').toString(),
      factualStatus: FactualStatus.fromString(
        (json['factual_status'] ?? json['factualStatus'])?.toString(),
      ),
      editorialStatus: ArticleEditorialStatus.fromString(
        (json['editorial_status'] ?? json['editorialStatus'])?.toString(),
      ),
      readingTimeMinutes: (json['reading_time_minutes'] as num?)?.toInt() ?? 5,
      publishedAt:
          DateTime.tryParse(json['published_at']?.toString() ?? '') ??
          DateTime.now(),
      officialSources: sources,
      canonicalPathwaySlug:
          json['canonical_pathway_slug']?.toString() ??
          json['canonicalPathwaySlug']?.toString(),
    );
  }
}
