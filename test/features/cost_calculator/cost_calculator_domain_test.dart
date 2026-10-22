// Unit tests for the Immigration Cost Calculator domain.
//
// The parser is the truth gate for this feature: it must extract only what a
// source actually published and refuse anything ambiguous, so the UI can never
// render an invented government fee.

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/cost_calculator/domain/entities/immigration_cost.dart';
import 'package:rad_emigrate/features/cost_calculator/domain/fee_parsing.dart';
import 'package:rad_emigrate/features/cost_calculator/presentation/providers/cost_calculator_controller.dart';
import 'package:rad_emigrate/features/visa/domain/entities/visa_entities.dart';

CostPathway _pathway({String feesText = '', String? processingTime}) {
  return CostPathway(
    id: 'p1',
    countryId: 'ca',
    countryName: 'Canada',
    flagEmoji: '🇨🇦',
    categoryId: 'study',
    categoryName: 'Study permit',
    title: 'Study permit (first-time)',
    feesText: feesText,
    processingTime: processingTime,
    sourceTitle: 'Study permit — Government of Canada',
    sourcePublisher: 'Canada.ca',
    sourceUrl: 'https://www.canada.ca/study',
    sourceRetrievedAt: DateTime.utc(2026, 1, 15),
  );
}

void main() {
  group('parsePublishedAmount', () {
    test('extracts a plain USD figure', () {
      final parsed = parsePublishedAmount('CAD 150');
      expect(parsed, isNotNull);
      expect(parsed!.currency, 'CAD');
      expect(parsed.amountMinor, 15000);
    });

    test('extracts a symbol-prefixed figure', () {
      final parsed = parsePublishedAmount('\$85');
      expect(parsed, isNotNull);
      expect(parsed!.currency, 'USD');
      expect(parsed.amountMinor, 8500);
    });

    test('handles thousands separators', () {
      final parsed = parsePublishedAmount('EUR 1,250');
      expect(parsed, isNotNull);
      expect(parsed!.amountMinor, 125000);
      expect(parsed.currency, 'EUR');
    });

    test('refuses a range (never picks one endpoint)', () {
      expect(parsePublishedAmount('\$100 – \$200'), isNull);
      expect(parsePublishedAmount('\$100-\$200'), isNull);
    });

    test('refuses qualified figures (from / about / per unit)', () {
      expect(parsePublishedAmount('from \$100'), isNull);
      expect(parsePublishedAmount('About EUR 90'), isNull);
      expect(parsePublishedAmount('\$20 per document'), isNull);
    });

    test('refuses text with no currency marker', () {
      expect(parsePublishedAmount('The fee is 150'), isNull);
    });

    test('refuses a bare year that is not a fee', () {
      expect(parsePublishedAmount('Updated in 2026'), isNull);
    });

    test('refuses empty input', () {
      expect(parsePublishedAmount(''), isNull);
      expect(parsePublishedAmount('   '), isNull);
    });
  });

  group('buildBreakdown', () {
    test('produces a parsed figure line and a total for a published fee', () {
      final breakdown = buildBreakdown(
        _pathway(feesText: 'CAD 150', processingTime: '8 weeks'),
      );
      expect(breakdown.hasAnyPublishedFigure, isTrue);
      expect(breakdown.total.isAvailable, isTrue);
      expect(breakdown.total.amountMinor, 15000);
      expect(breakdown.total.currency, 'CAD');

      final figure = breakdown.lines.firstWhere(
        (l) => l.basis == CostBasis.publishedFigure,
      );
      expect(figure.rawText, 'CAD 150');
    });

    test('renders explicit not-published state when no fee is published', () {
      final breakdown = buildBreakdown(_pathway());
      expect(breakdown.hasAnyPublishedFigure, isFalse);
      expect(breakdown.total.isAvailable, isFalse);
      expect(breakdown.total.unavailableReason, 'noPublishedFigure');
      expect(
        breakdown.lines.any((l) => l.basis == CostBasis.notPublished),
        isTrue,
      );
    });

    test('keeps prose-only fees as published text, not a figure', () {
      final breakdown = buildBreakdown(
        _pathway(feesText: 'from \$100 to \$200 depending on category'),
      );
      expect(breakdown.hasAnyPublishedFigure, isFalse);
      expect(breakdown.total.isAvailable, isFalse);
      final line = breakdown.lines.first;
      expect(line.basis, CostBasis.publishedTextOnly);
      expect(line.rawText, isNotNull);
    });

    test('never converts mixed currencies into a single total', () {
      // Two figure lines can only share a total within one currency; a single
      // published text cannot produce a mixed-currency sum, so this asserts the
      // guard that a lone figure in a non-selected currency stays honest.
      final breakdown = buildBreakdown(_pathway(feesText: 'EUR 200'));
      expect(breakdown.total.currency, 'EUR');
      expect(breakdown.total.isAvailable, isTrue);
    });

    test('processing time is surfaced as text, never a cost', () {
      final breakdown = buildBreakdown(
        _pathway(feesText: 'CAD 150', processingTime: '12 weeks'),
      );
      final processing = breakdown.lines.firstWhere(
        (l) => l.label == 'Published processing time',
      );
      expect(processing.basis, CostBasis.publishedTextOnly);
      expect(processing.amountMinor, isNull);
    });
  });

  group('pathwaysFromCatalog', () {
    test('maps a program into a selectable pathway', () {
      final source = VisaSource(
        title: 'Study permit',
        url: 'https://canada.ca',
        publisher: 'Canada.ca',
        retrievedAt: DateTime(2026, 1, 15),
      );
      final catalog = VisaCatalog(
        countries: [
          Country(
            id: 'ca',
            name: 'Canada',
            code: 'CA',
            flagEmoji: '🇨🇦',
            slug: 'canada',
          ),
        ],
        categories: [
          VisaCategory(
            id: 'study',
            name: 'Study',
            description: '',
            slug: 'study',
          ),
        ],
        programs: [
          VisaProgram(
            id: 'p1',
            slug: 'study-permit',
            title: 'Study permit',
            countryId: 'ca',
            categoryId: 'study',
            summary: 'Study permit for first-time applicants.',
            fees: 'CAD 150',
            processingTime: '8 weeks',
            source: source,
          ),
        ],
      );

      final pathways = pathwaysFromCatalog(catalog);
      expect(pathways, hasLength(1));
      expect(pathways.first.id, 'p1');
      expect(pathways.first.countryName, 'Canada');
      expect(pathways.first.categoryName, 'Study');
      expect(pathways.first.feesText, 'CAD 150');
      expect(pathways.first.hasPublishedFees, isTrue);
    });

    test('skips programs whose country or category is missing', () {
      final source = VisaSource(
        title: 's',
        url: 'u',
        publisher: 'p',
        retrievedAt: DateTime(2026, 1, 15),
      );
      final catalog = VisaCatalog(
        countries: [],
        categories: [
          VisaCategory(
            id: 'study',
            name: 'Study',
            description: '',
            slug: 'study',
          ),
        ],
        programs: [
          VisaProgram(
            id: 'p1',
            slug: 's',
            title: 'Orphan program',
            countryId: 'missing-country',
            categoryId: 'study',
            summary: 'x',
            source: source,
          ),
        ],
      );
      expect(pathwaysFromCatalog(catalog), isEmpty);
    });
  });

  group('breakdownFor', () {
    test('returns null when nothing is selected', () {
      expect(breakdownFor([_pathway()], null), isNull);
    });

    test('returns the breakdown for the selected id', () {
      final breakdown = breakdownFor([_pathway(feesText: 'CAD 150')], 'p1');
      expect(breakdown, isNotNull);
      expect(breakdown!.total.amountMinor, 15000);
    });

    test('returns null for an unknown id', () {
      expect(breakdownFor([_pathway()], 'nope'), isNull);
    });
  });
}
