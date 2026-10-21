import 'package:flutter/foundation.dart';

/// Range of matching character offsets within a search snippet or title.
@immutable
class MatchRange {
  final int start;
  final int end;

  const MatchRange({required this.start, required this.end});

  factory MatchRange.fromJson(Map<String, dynamic> json) {
    return MatchRange(
      start: (json['start'] as num?)?.toInt() ?? 0,
      end: (json['end'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
}

/// Type of article returned by search.
enum SearchArticleType {
  canonicalPathway,
  independentTopic;

  static SearchArticleType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'canonical_pathway':
      case 'canonical':
      case 'main':
        return SearchArticleType.canonicalPathway;
      case 'independent_topic':
      case 'independent':
      case 'related':
      default:
        return SearchArticleType.independentTopic;
    }
  }
}

/// Factual verification state decoupled from editorial lifecycle.
enum FactualStatus {
  verified,
  incorrect,
  incomplete,
  outdated,
  conflicting,
  unverified;

  static FactualStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'verified':
        return FactualStatus.verified;
      case 'incorrect':
        return FactualStatus.incorrect;
      case 'incomplete':
        return FactualStatus.incomplete;
      case 'outdated':
        return FactualStatus.outdated;
      case 'conflicting':
        return FactualStatus.conflicting;
      case 'unverified':
      default:
        return FactualStatus.unverified;
    }
  }

  String toDisplayPersian() {
    switch (this) {
      case FactualStatus.verified:
        return 'تأییدشده رسمی';
      case FactualStatus.incorrect:
        return 'نادرست / ردشده';
      case FactualStatus.incomplete:
        return 'نیازمند تکمیل';
      case FactualStatus.outdated:
        return 'منسوخ / به‌روزرسانی نشده';
      case FactualStatus.conflicting:
        return 'دارای مغایرت';
      case FactualStatus.unverified:
        return 'در انتظار بررسی';
    }
  }
}

/// Individual hit in Smart Search results.
@immutable
class SearchHit {
  final String id;
  final String title;
  final String slug;
  final String countryCode;
  final String countryName;
  final String category;
  final String snippet;
  final List<MatchRange> matchRanges;
  final String? targetSectionAnchor;
  final double relevanceScore;
  final FactualStatus factualStatus;
  final SearchArticleType articleType;
  final String deepLinkRoute;

  const SearchHit({
    required this.id,
    required this.title,
    required this.slug,
    required this.countryCode,
    required this.countryName,
    required this.category,
    required this.snippet,
    required this.matchRanges,
    this.targetSectionAnchor,
    required this.relevanceScore,
    required this.factualStatus,
    required this.articleType,
    required this.deepLinkRoute,
  });

  factory SearchHit.fromJson(Map<String, dynamic> json) {
    final rawRanges =
        json['match_ranges'] as List? ?? json['matchRanges'] as List? ?? [];
    final ranges = rawRanges
        .whereType<Map<String, dynamic>>()
        .map((m) => MatchRange.fromJson(m))
        .toList();

    final cCode = (json['country_code'] ?? json['countryCode'] ?? '')
        .toString();
    final aSlug = (json['slug'] ?? json['pathway_slug'] ?? '').toString();
    final rawType =
        (json['article_kind'] ?? json['article_type'] ?? json['articleType'])
            ?.toString();
    final type = SearchArticleType.fromString(rawType);
    final anchor =
        json['target_section_anchor'] ??
        json['targetSectionAnchor'] ??
        json['section_anchor'];

    // Construct deep link route
    String route;
    if (type == SearchArticleType.canonicalPathway) {
      route = '/visa/$cCode/$aSlug';
    } else {
      route = '/visa/$cCode/articles/$aSlug';
    }
    if (anchor != null && anchor.toString().isNotEmpty) {
      route = '$route#$anchor';
    }
    // Canonical SearchHit has UUID targets, not country/slug routing fields.
    final target = json['target'];
    if (target is Map && target['kind'] == 'visa_article') {
      route = Uri(
        path: '/visa/articles/${target['id']}',
        queryParameters: target['section_id'] == null
            ? null
            : {'section': target['section_id'].toString()},
        fragment: anchor == null || anchor.toString().isEmpty
            ? null
            : anchor.toString(),
      ).toString();
    }

    return SearchHit(
      id: (json['id'] ?? json['article_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      slug: aSlug,
      countryCode: cCode,
      countryName: (json['country_name'] ?? json['countryName'] ?? '')
          .toString(),
      category: (json['category'] ?? '').toString(),
      snippet: (json['snippet'] ?? '').toString(),
      matchRanges: ranges,
      targetSectionAnchor: anchor?.toString(),
      relevanceScore:
          double.tryParse(json['relevance_score']?.toString() ?? '') ??
          double.tryParse(json['score']?.toString() ?? '') ??
          1.0,
      factualStatus: FactualStatus.fromString(
        (json['factual_status'] ??
                json['factualStatus'] ??
                json['verification_state'])
            ?.toString(),
      ),
      articleType: type,
      deepLinkRoute: route,
    );
  }
}

/// Aggregated response of a Smart Search query.
@immutable
class SmartSearchResult {
  final String query;
  final int totalCount;
  final List<SearchHit> hits;
  final String? correctedQuery;
  final int tookMs;

  const SmartSearchResult({
    required this.query,
    required this.totalCount,
    required this.hits,
    this.correctedQuery,
    this.tookMs = 0,
  });

  factory SmartSearchResult.empty(String query) =>
      SmartSearchResult(query: query, totalCount: 0, hits: const []);

  factory SmartSearchResult.fromJson(
    Map<String, dynamic> json, {
    String query = '',
  }) {
    // Backend wire response envelopes data in json['data']['items']
    final dataMap = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawHits =
        dataMap['items'] as List? ??
        dataMap['hits'] as List? ??
        json['hits'] as List? ??
        [];
    return SmartSearchResult(
      query:
          dataMap['query_normalized']?.toString() ??
          json['query']?.toString() ??
          query,
      totalCount:
          (dataMap['total_count'] as num?)?.toInt() ??
          (json['total_count'] as num?)?.toInt() ??
          rawHits.length,
      hits: rawHits
          .whereType<Map<String, dynamic>>()
          .map((h) => SearchHit.fromJson(h))
          .toList(),
      correctedQuery:
          dataMap['corrected_query']?.toString() ??
          json['corrected_query']?.toString(),
      tookMs: (json['took_ms'] as num?)?.toInt() ?? 0,
    );
  }
}
