// Country and Pathway comparison domain entities.
//
// Accurately presents factual comparison criteria between immigration pathways.
// Never fabricates eligibility or official processing guarantees.

class PathwayComparisonItem {
  const PathwayComparisonItem({
    required this.countryCode,
    required this.countryName,
    required this.pathwaySlug,
    required this.pathwayName,
    required this.minLanguageLevel,
    required this.processingTimeRange,
    required this.jobOfferRequired,
    required this.directPermanentResidency,
    required this.keyAdvantage,
    required this.keyRequirement,
  });

  final String countryCode;
  final String countryName;
  final String pathwaySlug;
  final String pathwayName;
  final String minLanguageLevel;
  final String processingTimeRange;
  final bool jobOfferRequired;
  final bool directPermanentResidency;
  final String keyAdvantage;
  final String keyRequirement;
}
