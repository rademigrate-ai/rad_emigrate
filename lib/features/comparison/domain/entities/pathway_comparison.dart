// Country and pathway comparison domain.
//
// A comparison cell is either verified (sourced from published catalog text),
// explicitly marked as unpublished, or carries prose. No eligibility, cost, or
// timeline is ever invented — [ComparisonField.missing] renders an explicit
// "not published" indicator in the UI.

/// Minimal shape the comparison needs, decoupled from the visa entity so the
/// domain stays testable without the data layer.
class VisaProgramLike {
  const VisaProgramLike({
    required this.id,
    required this.countryName,
    required this.flagEmoji,
    required this.title,
    required this.categoryName,
    required this.sourceTitle,
    required this.sourcePublisher,
    required this.sourceUrl,
    required this.sourceRetrievedAt,
    this.processingTime,
    this.fees,
    this.requirements = const [],
  });

  final String id;
  final String countryName;
  final String flagEmoji;
  final String title;
  final String categoryName;
  final String? processingTime;
  final String? fees;
  final List<String> requirements;
  final String sourceTitle;
  final String sourcePublisher;
  final String sourceUrl;
  final DateTime sourceRetrievedAt;
}

/// One comparable attribute of a pathway.
enum ComparisonField {
  country,
  pathway,
  category,
  processingTime,
  fees,
  requirements,
}

/// Trust status of a single cell.
enum CellStatus {
  /// Published figure/text backed by a source.
  published,

  /// The catalog publishes nothing for this attribute.
  missing,

  /// Published as prose that is not a single verifiable value.
  prose,
}

/// A single cell in the comparison grid.
class ComparisonCell {
  const ComparisonCell(this.status, {this.text, this.items})
    : assert(
        status != CellStatus.published || text != null || items != null,
        'A published cell must carry its value.',
      );

  const ComparisonCell.publishedText(String this.text)
    : status = CellStatus.published,
      items = null;

  const ComparisonCell.publishedList(List<String> this.items)
    : status = CellStatus.published,
      text = null;

  const ComparisonCell.missing()
    : status = CellStatus.missing,
      text = null,
      items = null;

  const ComparisonCell.prose(String this.text)
    : status = CellStatus.prose,
      items = null;

  final CellStatus status;
  final String? text;
  final List<String>? items;

  bool get isPublished => status == CellStatus.published;
  bool get isMissing => status == CellStatus.missing;
}

/// One pathway column in the comparison.
class ComparisonEntry {
  const ComparisonEntry({
    required this.id,
    required this.countryName,
    required this.flagEmoji,
    required this.pathwayTitle,
    required this.categoryName,
    required this.processingTime,
    required this.fees,
    required this.requirements,
    required this.sourceTitle,
    required this.sourcePublisher,
    required this.sourceUrl,
    required this.sourceRetrievedAt,
  });

  final String id;
  final String countryName;
  final String flagEmoji;
  final String pathwayTitle;
  final String categoryName;

  final ComparisonCell processingTime;
  final ComparisonCell fees;
  final ComparisonCell requirements;

  final String sourceTitle;
  final String sourcePublisher;
  final String sourceUrl;
  final DateTime sourceRetrievedAt;

  ComparisonCell cellFor(ComparisonField field) => switch (field) {
    ComparisonField.country => ComparisonCell.publishedText(countryName),
    ComparisonField.pathway => ComparisonCell.publishedText(pathwayTitle),
    ComparisonField.category => ComparisonCell.publishedText(categoryName),
    ComparisonField.processingTime => processingTime,
    ComparisonField.fees => fees,
    ComparisonField.requirements => requirements,
  };
}

/// Builds comparison entries from verified visa programs.
List<ComparisonEntry> entriesFromPrograms(List<VisaProgramLike> programs) {
  return programs
      .map((p) {
        final processing = p.processingTime?.trim();
        final fees = p.fees?.trim();
        final requirementTexts = p.requirements
            .map((r) => r.trim())
            .where((r) => r.isNotEmpty)
            .toList();
        return ComparisonEntry(
          id: p.id,
          countryName: p.countryName,
          flagEmoji: p.flagEmoji,
          pathwayTitle: p.title,
          categoryName: p.categoryName,
          processingTime: (processing == null || processing.isEmpty)
              ? const ComparisonCell.missing()
              : ComparisonCell.prose(processing),
          fees: (fees == null || fees.isEmpty)
              ? const ComparisonCell.missing()
              : ComparisonCell.prose(fees),
          requirements: requirementTexts.isEmpty
              ? const ComparisonCell.missing()
              : ComparisonCell.publishedList(requirementTexts),
          sourceTitle: p.sourceTitle,
          sourcePublisher: p.sourcePublisher,
          sourceUrl: p.sourceUrl,
          sourceRetrievedAt: p.sourceRetrievedAt,
        );
      })
      .toList(growable: false);
}
