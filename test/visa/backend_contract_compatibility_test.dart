// Synthetic parser fixtures only; no rates or immigration claims here are operational evidence.
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/services/ai/ai_response.dart';
import 'package:rad_emigrate/features/visa/domain/entities/canonical_pathway_entities.dart';
import 'package:rad_emigrate/features/visa/domain/entities/fx_rate.dart';
import 'package:rad_emigrate/features/visa/domain/entities/search_entities.dart';

void main() {
  group('Backend Contract Compatibility & Wire Schema Tests', () {
    test('SmartSearchResult correctly unwraps rad_v1 data.items envelope', () {
      final wireJson = {
        'data': {
          'items': [
            {
              'article_id': 'c8f42045-812e-4b68-b715-46f903a49f53',
              'revision_id': 'a1111111-2222-3333-4444-555555555555',
              'revision': 1,
              'article_kind': 'main',
              'title': 'ویزای کارت شانس آلمان (Chancenkarte)',
              'section_id': 'b2222222-3333-4444-5555-666666666666',
              'section_anchor': 'financial-requirements',
              'snippet': 'مبلغ تمکن مالی برای کارت شانس ماهانه ۱,۰۲۷ یورو است.',
              'match_locale': 'fa',
              'match_kind': 'full_text',
              'score': '0.94',
              'verification_state': 'verified',
              'freshness_state': 'fresh',
              'target': {
                'kind': 'visa_article',
                'id': 'c8f42045-812e-4b68-b715-46f903a49f53',
                'section_id': 'b2222222-3333-4444-5555-666666666666',
              },
              'country_code': 'DE',
              'slug': 'chancenkarte',
              'match_ranges': [
                {'start': 24, 'end': 34},
              ],
            },
            {
              'article_id': 'd9999999-812e-4b68-b715-46f903a49f54',
              'revision_id': 'a2222222-2222-3333-4444-555555555555',
              'revision': 2,
              'article_kind': 'related',
              'title': 'افتتاح حساب بلوکه‌شده (Sperrkonto)',
              'section_id': null,
              'section_anchor': '',
              'snippet': 'راهنمای گام‌به‌گام حساب مسدودشده در بانک‌های آلمان.',
              'match_locale': 'fa',
              'match_kind': 'full_text',
              'score': '0.82',
              'verification_state': 'verified',
              'freshness_state': 'fresh',
              'target': {
                'kind': 'visa_article',
                'id': 'd9999999-812e-4b68-b715-46f903a49f54',
                'section_id': null,
              },
              'country_code': 'DE',
              'slug': 'sperrkonto-guide',
              'match_ranges': [
                {'start': 0, 'end': 15},
              ],
            },
          ],
          'index_version': 'v1.4',
          'query_normalized': 'تمکن مالی کارت شانس',
          'evidence_state': 'available',
        },
        'meta': {'request_id': 'req-123', 'timestamp': '2026-10-20T00:00:00Z'},
        'page': {'has_more': false, 'next_cursor': null},
      };

      final result = SmartSearchResult.fromJson(wireJson);
      expect(result.hits.length, 2);
      expect(result.query, 'تمکن مالی کارت شانس');

      final hit1 = result.hits[0];
      expect(hit1.id, 'c8f42045-812e-4b68-b715-46f903a49f53');
      expect(hit1.articleType, SearchArticleType.canonicalPathway);
      expect(hit1.factualStatus, FactualStatus.verified);
      expect(
        hit1.deepLinkRoute,
        '/visa/articles/c8f42045-812e-4b68-b715-46f903a49f53?section=b2222222-3333-4444-5555-666666666666#financial-requirements',
      );
      expect(hit1.matchRanges.length, 1);
      expect(hit1.matchRanges.first.start, 24);
      expect(hit1.matchRanges.first.end, 34);

      final hit2 = result.hits[1];
      expect(hit2.id, 'd9999999-812e-4b68-b715-46f903a49f54');
      expect(hit2.articleType, SearchArticleType.independentTopic);
      expect(
        hit2.deepLinkRoute,
        '/visa/articles/d9999999-812e-4b68-b715-46f903a49f54',
      );
    });

    test('CanonicalPathwayArticle parses wire data with structured blocks', () {
      final wireJson = {
        'data': {
          'id': 'art-de-chancenkarte',
          'kind': 'main',
          'country_code': 'DE',
          'pathway_slug': 'chancenkarte',
          'locale': 'fa',
          'title': 'کارت شانس آلمان',
          'summary': 'فرصت یک‌ساله جستجوی کار برای متخصصان بین‌المللی.',
          'editorial_state': 'published',
          'verification_state': 'verified',
          'freshness_state': 'fresh',
          'revision': 3,
          'sections': [
            {
              'id': 'sec-01',
              'anchor': 'general-overview',
              'heading': 'مرور کلی مسیر',
              'order': 1,
              'blocks': [
                {
                  'id': 'blk-01',
                  'type': 'paragraph',
                  'text': 'کارت شانس بر اساس سیستم امتیازبندی عمل می‌کند.',
                  'items': [],
                },
                {
                  'id': 'blk-02',
                  'type': 'bullet_list',
                  'text': '',
                  'items': ['حداقل ۶ امتیاز', 'مدرک ب۲ آلمانی یا ب۲ انگلیسی'],
                },
              ],
              'evidence': [],
            },
          ],
          'official_sources': [
            {
              'authority_name': 'Make it in Germany',
              'authority_domain': 'make-it-in-germany.com',
              'original_evidence_url': 'https://www.make-it-in-germany.com/en/visa-residence/types/job-search-opportunity-card',
              'last_fact_checked_at': '2026-10-18T10:00:00Z',
              'factual_status': 'verified',
            },
          ],
          'costs': [
            {
              'label': 'هزینه درخواست ویزا',
              'amount': 75.0,
              'currency': 'EUR',
              'is_refundable': false,
            },
          ],
          'steps': [
            {
              'step_number': 1,
              'title': 'محاسبه امتیازات',
              'description': 'محاسبه امتیاز در سیستم خودارزیابی رسمی.',
              'estimated_weeks': 1,
            },
          ],
          'required_documents': [
            'پاسپورت معتبر',
            'رزومه استاندارد اروپایی Europass',
          ],
          'related_articles': [
            {
              'id': 'rel-01',
              'slug': 'sperrkonto-guide',
              'title': 'حساب بلوکه',
              'country_code': 'DE',
              'summary': 'راهنمای حساب مسدودشده',
              'category': 'مالی',
            },
          ],
        },
      };

      final article = CanonicalPathwayArticle.fromJson(wireJson);
      expect(article.id, 'art-de-chancenkarte');
      expect(article.slug, 'chancenkarte');
      expect(article.countryCode, 'DE');
      expect(article.pathwayTitle, 'کارت شانس آلمان');
      expect(article.editorialStatus, ArticleEditorialStatus.published);
      expect(article.factualStatus, FactualStatus.verified);
      expect(article.sections.length, 1);
      expect(article.sections.first.title, 'مرور کلی مسیر');
      expect(
        article.sections.first.bodyMarkdown,
        contains('کارت شانس بر اساس سیستم امتیازبندی عمل می‌کند.'),
      );
      expect(article.sections.first.bodyMarkdown, contains('حداقل ۶ امتیاز'));
      expect(article.officialSources.length, 1);
      expect(
        article.officialSources.first.authorityDomain,
        'make-it-in-germany.com',
      );
      expect(article.costs.first.amount, 75.0);
      expect(article.costs.first.currency, 'EUR');
    });

    test(
      'FxRateQuote strictly validates provider_reference from wire response',
      () {
        final wireJson = {
          'data': {
            'id': 'e3333333-3333-4333-8333-333333333333',
            'provider': 'fawazahmed0',
            'base': 'EUR',
            'quote': 'IRR',
            'rate': '485200.00',
            'rate_basis': 'provider_reference',
            'observation_date': '2026-10-19',
            'fetched_at': '2026-10-19T14:30:00Z',
            'freshness_state': 'fresh',
            'source_url': 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json',
          },
          'meta': {'request_id': 'fx-req-1'},
        };

        final quote = FxRateQuote.fromJson(wireJson['data']!);
        expect(quote.provider, FxProvider.fawazahmed0);
        expect(quote.baseCurrency, 'EUR');
        expect(quote.quoteCurrency, 'IRR');
        expect(quote.referenceRate, 485200.0);
        expect(quote.rateBasis, RateBasis.providerReference);
        expect(quote.freshnessState, FreshnessState.fresh);

        final conversion = quote.convert(1027.0);
        expect(conversion.amountIrr, 1027.0 * 485200.0);
        expect(conversion.amountToman, (1027.0 * 485200.0) / 10.0);
      },
    );

    test('AiResponse accurately handles citations and evidence states', () {
      final citation = AiSource(
        title: 'BAMF Germany Chancenkarte Requirements',
        url: 'https://www.bamf.de/chancenkarte',
        authority: 'BAMF',
      );
      final response = AiResponse(
        text: 'برای دریافت کارت شانس باید حداقل ۶ امتیاز کسب کنید.',
        sources: [citation],
        uncertain: false,
        conversationId: 'conv-123',
      );

      expect(response.sources.length, 1);
      expect(response.sources.first.authority, 'BAMF');
      expect(response.uncertain, isFalse);
    });
  });
}
