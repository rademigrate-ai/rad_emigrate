// Published-fee parsing for the cost calculator.
//
// A figure is only ever extracted from text that a source actually published.
// The parser is deliberately conservative: it recognises explicit amounts with
// a currency marker and refuses anything ambiguous (ranges, "from"/"about",
// per-unit prices). When it cannot be sure, it returns
// [CostBasis.publishedTextOnly] and preserves the raw text so the UI shows the
// authoritative wording instead of a fabricated number.

import 'entities/immigration_cost.dart';

class ParsedAmount {
  const ParsedAmount(this.amountMinor, this.currency);

  final int amountMinor;
  final String currency;
}

final RegExp _digits = RegExp(r'\d');

/// Currency symbols/prefixes mapped to ISO codes.
const Map<String, String> _currencyMarkers = {
  r'US\$': 'USD',
  r'CA\$': 'CAD',
  r'A\$': 'AUD',
  r'€': 'EUR',
  r'£': 'GBP',
  r'₺': 'TRY',
  r'$': 'USD',
};

const Map<String, String> _isoMarkers = {
  'USD': 'USD',
  'EUR': 'EUR',
  'GBP': 'GBP',
  'CAD': 'CAD',
  'AUD': 'AUD',
  'TRY': 'TRY',
  'AED': 'AED',
};

/// Returns a single explicit figure, or null when the text does not state one
/// unambiguously.
ParsedAmount? parsePublishedAmount(String raw) {
  final text = raw.trim();
  if (text.isEmpty || !_digits.hasMatch(text)) return null;

  // Ambiguous phrasing: a range or qualifier means no single verifiable total.
  final lower = text.toLowerCase();
  if (lower.contains('from') ||
      lower.contains('about') ||
      lower.contains('approx') ||
      lower.contains('starting') ||
      lower.contains('per ') ||
      text.contains('–') ||
      text.contains('—') ||
      // A hyphen or slash between two figures is a range. Up to four
      // non-digit characters may sit on each side of the separator (currency
      // symbols, spaces): "$100-$200", "$100 - $200", "100/200". Digits must
      // flank it so a single figure like "150" is never mistaken for a range.
      RegExp(r'\d\D{0,4}[-/]\D{0,4}\d').hasMatch(text)) {
    return null;
  }

  // Locate a currency marker first (symbol or ISO code).
  String? currency;
  for (final entry in _currencyMarkers.entries) {
    if (text.contains(entry.key)) {
      currency = entry.value;
      break;
    }
  }
  if (currency == null) {
    for (final entry in _isoMarkers.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(text)) {
        currency = entry.value;
        break;
      }
    }
  }
  if (currency == null) return null;

  // Extract the first number, tolerating thousands separators and decimals.
  final numberMatch = RegExp(r'\d[\d, ]*(?:\.\d+)?').firstMatch(text);
  if (numberMatch == null) return null;
  final cleaned = numberMatch.group(0)!.replaceAll(RegExp(r'[,\s]'), '');
  final asDouble = double.tryParse(cleaned);
  if (asDouble == null) return null;
  // Guard against junk like "2026" being read as a fee year.
  if (asDouble > 1000000) return null;
  return ParsedAmount((asDouble * 100).round(), currency);
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
