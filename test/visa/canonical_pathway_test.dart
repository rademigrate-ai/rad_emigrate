import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/visa/data/canonical_pathway_repository.dart';
import 'package:rad_emigrate/features/visa/domain/entities/canonical_pathway_entities.dart';
import 'package:rad_emigrate/features/visa/domain/entities/search_entities.dart';

void main() {
  group('Canonical Pathway & Independent Articles Domain Tests', () {
    test(
      'CanonicalPathwayArticle preserves decoupled factual vs editorial status',
      () {
        final article = CanonicalPathwayArticle(
          id: 'de-chancenkarte',
          slug: 'chancenkarte',
          countryCode: 'de',
          countryName: 'آلمان',
          countryFlag: '🇩🇪',
          pathwayTitle: 'Chancenkarte',
          category: 'کاری',
          factualStatus: FactualStatus.verified,
          editorialStatus: ArticleEditorialStatus.published,
          summary: 'راهنمای کارت فرصت',
          officialSources: [
            OfficialSourceAttribution(
              authorityName: 'Make it in Germany',
              authorityDomain: 'make-it-in-germany.com',
              originalEvidenceUrl: 'https://make-it-in-germany.com',
              lastFactCheckedAt: DateTime.now(),
              factualStatus: FactualStatus.verified,
            ),
          ],
          sections: [
            const PathwaySection(
              id: 'sec-1',
              anchor: 'overview',
              title: 'معرفی',
              bodyMarkdown: 'متن',
              displayOrder: 1,
            ),
          ],
          costs: const [
            PathwayFinancialCostItem(
              label: 'تمکن ماهانه',
              amount: 1027.0,
              currency: 'EUR',
            ),
          ],
          steps: const [
            PathwayProcessStep(
              stepNumber: 1,
              title: 'آنابین',
              description: 'ارزیابی مدرک',
            ),
          ],
          requiredDocuments: const ['پاسپورت'],
          faqItems: const [],
          relatedArticles: const [],
          lastFactCheckedAt: DateTime.now(),
        );

        expect(article.factualStatus, FactualStatus.verified);
        expect(article.editorialStatus, ArticleEditorialStatus.published);
        expect(
          article.officialSources.first.authorityDomain,
          'make-it-in-germany.com',
        );
        expect(article.costs.first.amount, 1027.0);
      },
    );

    test(
      'CanonicalPathwayRepository leaves main content unavailable offline',
      () async {
        final repo = SupabaseCanonicalPathwayRepository(
          SupabaseClientService.instance,
        );
        final article = await repo.getCanonicalPathway(
          countryCode: 'de',
          pathwaySlug: 'chancenkarte',
        );

        expect(SupabaseClientService.instance.isInitialized, isFalse);
        expect(article, isNull);
      },
    );

    test(
      'CanonicalPathwayRepository leaves related content unavailable offline',
      () async {
        final repo = SupabaseCanonicalPathwayRepository(
          SupabaseClientService.instance,
        );
        final article = await repo.getIndependentArticle(
          countryCode: 'de',
          articleSlug: 'sperrkonto-guide',
        );

        expect(SupabaseClientService.instance.isInitialized, isFalse);
        expect(article, isNull);
      },
    );
  });
}
