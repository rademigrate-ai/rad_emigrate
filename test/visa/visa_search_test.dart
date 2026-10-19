import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/visa/data/visa_search_repository.dart';
import 'package:rad_emigrate/features/visa/domain/entities/search_entities.dart';

void main() {
  group('Visa Smart Search Tests', () {
    test('SearchHit correctly constructs deep link routes and anchors', () {
      final hitCanonical = SearchHit(
        id: 'de-chancenkarte',
        title: 'Chancenkarte',
        slug: 'chancenkarte',
        countryCode: 'de',
        countryName: 'آلمان',
        category: 'کاری',
        snippet: 'توضیحات کارت فرصت',
        matchRanges: [const MatchRange(start: 0, end: 4)],
        targetSectionAnchor: 'points',
        relevanceScore: 0.95,
        factualStatus: FactualStatus.verified,
        articleType: SearchArticleType.canonicalPathway,
        deepLinkRoute: '/visa/de/chancenkarte#points',
      );

      expect(hitCanonical.deepLinkRoute, '/visa/de/chancenkarte#points');
      expect(hitCanonical.articleType, SearchArticleType.canonicalPathway);
      expect(hitCanonical.factualStatus, FactualStatus.verified);

      final hitIndependent = SearchHit.fromJson({
        'id': 'de-sperrkonto',
        'title': 'Sperrkonto Guide',
        'slug': 'sperrkonto-guide',
        'country_code': 'de',
        'country_name': 'آلمان',
        'category': 'مالی',
        'snippet': 'راهنمای حساب مسدود',
        'target_section_anchor': 'fees',
        'article_type': 'independent_topic',
        'factual_status': 'verified',
        'match_ranges': [
          {'start': 0, 'end': 3},
        ],
      });

      expect(
        hitIndependent.deepLinkRoute,
        '/visa/de/articles/sperrkonto-guide#fees',
      );
      expect(hitIndependent.matchRanges.length, 1);
      expect(hitIndependent.matchRanges.first.start, 0);
      expect(hitIndependent.matchRanges.first.end, 3);
    });

    test('VisaSearchRepository returns matching hits and calculates character match ranges', () async {
      final repo = SupabaseVisaSearchRepository(SupabaseClientService.instance);
      final result = await repo.searchArticles(query: 'مسدود');

      expect(result.hits.isNotEmpty, isTrue);
      final hit = result.hits.first;
      expect(hit.snippet.contains('مسدود'), isTrue);
      expect(hit.matchRanges.isNotEmpty, isTrue);
    });

    test('VisaSearchRepository handles empty queries gracefully', () async {
      final repo = SupabaseVisaSearchRepository(SupabaseClientService.instance);
      final result = await repo.searchArticles(query: '');

      expect(result.totalCount, 0);
      expect(result.hits, isEmpty);
    });
  });
}
