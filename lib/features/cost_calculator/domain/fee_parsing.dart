// Published-fee parsing for the cost calculator.
//
// A figure is only ever extracted from text that a source actually published.
// The parser is deliberately conservative: it recognises explicit amounts with
// a currency marker and refuses anything ambiguous (ranges, "from"/"about",
// per-unit prices). When it cannot be sure, it returns
// [CostBasis.publishedTextOnly] and preserves the raw text so the UI shows the
// original wording instead of a fabricated number.

import 'entities/immigration_cost.dart';

class ParsedAmount {
  const ParsedAmount(this.amountMinor, this.currency);

  final int amountMinor;
  final String currency;
}

/// Parses only a complete single amount/currency expression. Legacy prose is
/// displayed verbatim, never searched for a convenient first number.
ParsedAmount? parsePublishedAmount(String raw) {
  const codes = {'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'TRY', 'AED'};
  const symbols = {
    r'US$': 'USD',
    r'CA$': 'CAD',
    r'A$': 'AUD',
    '€': 'EUR',
    '£': 'GBP',
    '₺': 'TRY',
    r'$': 'USD',
  };
  final text = raw.trim();
  final token = RegExp(
    r'^(?:(USD|EUR|GBP|CAD|AUD|TRY|AED)\s*)?(US\$|CA\$|A\$|\$|€|£|₺)?\s*((?:0|[1-9][0-9]*|[1-9][0-9]{0,2}(?:,[0-9]{3})+)(?:\.[0-9]{1,2})?)\s*(USD|EUR|GBP|CAD|AUD|TRY|AED|€|£|₺)?$',
  ).firstMatch(text);
  if (token == null) return null;
  final iso = token[1];
  final symbol = token[2];
  final suffix = token[4];
  final currencies = <String>{};
  if (iso != null) currencies.add(iso);
  if (suffix != null) {
    currencies.add(codes.contains(suffix) ? suffix : symbols[suffix]!);
  }
  // An unqualified $ is disambiguated by an explicit ISO code, e.g. CAD $150.
  if (symbol != null &&
      !(symbol == r'$' &&
          currencies.any((c) => {'USD', 'CAD', 'AUD'}.contains(c)))) {
    currencies.add(symbols[symbol]!);
  }
  if (currencies.length != 1) return null;
  final parts = token[3]!.replaceAll(',', '').split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 1000000) return null;
  final minor =
      whole * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return ParsedAmount(minor, currencies.single);
}

/// Builds the full breakdown for one pathway from its published fields.
CostBreakdown buildBreakdown(CostPathway pathway) {
  final lines = <CostLine>[];

  final feeRaw = pathway.feesText.trim();
  if (feeRaw.isEmpty) {
    lines.add(
      const CostLine(
        label: 'Government & application fees',
        basis: CostBasis.notPublished,
      ),
    );
  } else {
    final parsed = parsePublishedAmount(feeRaw);
    if (parsed != null) {
      lines.add(
        CostLine(
          label: 'Government & application fees',
          basis: CostBasis.publishedFigure,
          amountMinor: parsed.amountMinor,
          currency: parsed.currency,
          rawText: feeRaw,
        ),
      );
    } else {
      lines.add(
        CostLine(
          label: 'Government & application fees',
          basis: CostBasis.publishedTextOnly,
          rawText: feeRaw,
        ),
      );
    }
  }

  // Processing duration is published as text, never converted into a cost.
  if (pathway.processingTime != null &&
      pathway.processingTime!.trim().isNotEmpty) {
    lines.add(
      CostLine(
        label: 'Published processing time',
        basis: CostBasis.publishedTextOnly,
        rawText: pathway.processingTime!.trim(),
      ),
    );
  }

  return CostBreakdown(pathway: pathway, lines: lines, total: _totalFor(lines));
}

CostTotal _totalFor(List<CostLine> lines) {
  final figures = lines
      .where((l) => l.basis == CostBasis.publishedFigure)
      .toList();
  if (figures.isEmpty) {
    return const CostTotal.unavailable('noPublishedFigure');
  }
  final currency = figures.first.currency;
  if (currency == null) {
    return const CostTotal.unavailable('unknownCurrency');
  }
  for (final figure in figures) {
    if (figure.currency != currency) {
      // Mixed currencies without a verified FX rate: never guess a conversion.
      return const CostTotal.unavailable('mixedCurrenciesNoRate');
    }
  }
  final sum = figures.fold<int>(0, (acc, l) => acc + (l.amountMinor ?? 0));
  return CostTotal.available(amountMinor: sum, currency: currency);
}
