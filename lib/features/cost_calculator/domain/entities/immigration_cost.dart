// Immigration cost calculator domain.
//
// Every amount shown here derives from published, source-attributed catalog
// text (VisaProgram.fees). Nothing is invented: when a parseable figure is not
// available the line item is [CostBasis.notPublished] and the UI must render an
// explicit "not published" state rather than a number.

/// A single selectable destination + pathway.
class CostPathway {
  const CostPathway({
    required this.id,
    required this.countryId,
    required this.countryName,
    required this.flagEmoji,
    required this.categoryId,
    required this.categoryName,
    required this.title,
    required this.feesText,
    required this.processingTime,
    required this.sourceTitle,
    required this.sourcePublisher,
    required this.sourceUrl,
    required this.sourceRetrievedAt,
  });

  final String id;
  final String countryId;
  final String countryName;
  final String flagEmoji;
  final String categoryId;
  final String categoryName;
  final String title;

  /// Published fee text exactly as sourced; empty when the catalog has none.
  final String feesText;
  final String? processingTime;

  final String sourceTitle;
  final String sourcePublisher;
  final String sourceUrl;
  final DateTime sourceRetrievedAt;

  bool get hasPublishedFees => feesText.trim().isNotEmpty;
}

/// How a cost line was derived — surfaced so the user can judge trust.
enum CostBasis {
  /// An exact figure was parsed from published, source-attributed text.
  publishedFigure,

  /// Published text exists but carries no single parseable figure.
  publishedTextOnly,

  /// The catalog publishes no figure for this line.
  notPublished,
}

/// One row in the cost breakdown.
class CostLine {
  const CostLine({
    required this.label,
    required this.basis,
    this.amountMinor,
    this.currency,
    this.rawText,
  });

  final String label;
  final CostBasis basis;

  /// Parsed figure in minor units (e.g. cents) when [basis] is a figure.
  final int? amountMinor;

  /// ISO currency extracted from the raw text when detectable.
  final String? currency;

  /// The verbatim published text backing this line.
  final String? rawText;

  bool get isParsedFigure => basis == CostBasis.publishedFigure;
}

/// Subtotal of parsed fee figures only; excludes unknown/unlisted costs.
class CostTotal {
  const CostTotal.available({required this.amountMinor, required this.currency})
    : isAvailable = true,
      unavailableReason = null;

  const CostTotal.unavailable(this.unavailableReason)
    : isAvailable = false,
      amountMinor = null,
      currency = null;

  final bool isAvailable;
  final int? amountMinor;
  final String? currency;
  final String? unavailableReason;
}

/// Result of a calculation for one pathway.
class CostBreakdown {
  const CostBreakdown({
    required this.pathway,
    required this.lines,
    required this.total,
  });

  final CostPathway pathway;
  final List<CostLine> lines;
  final CostTotal total;

  bool get hasAnyPublishedFigure => lines.any((l) => l.isParsedFigure);
}
