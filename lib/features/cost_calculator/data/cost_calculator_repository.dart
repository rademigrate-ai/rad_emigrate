import '../domain/entities/cost_estimate.dart';

abstract class CostCalculatorRepository {
  Future<CostEstimateResult> calculatePathwayCosts({
    required String countryCode,
    required String pathwaySlug,
    required int applicantsCount,
    required String locale,
  });
}

/// Cost estimates require Backend-approved fee catalogs.
/// This repository never invents official fees, tuition, or proof-of-funds.
class StaticCostCalculatorRepository implements CostCalculatorRepository {
  const StaticCostCalculatorRepository();

  @override
  Future<CostEstimateResult> calculatePathwayCosts({
    required String countryCode,
    required String pathwaySlug,
    required int applicantsCount,
    required String locale,
  }) async {
    final isFa = locale == 'fa';
    return CostEstimateResult(
      countryCode: countryCode.toUpperCase(),
      countryName: countryCode.toUpperCase(),
      pathwaySlug: pathwaySlug,
      pathwayName: pathwaySlug,
      baseCurrency: 'EUR',
      disclaimer: isFa
          ? 'O\u062c\u062f\u0648\u0644 \u0631\u0633\u0645\u06cc \u0647\u0632\u06cc\u0646\u0647\u200c\u0647\u0627 \u0627\u0632 \u06a9\u0627\u062a\u0627\u0644\u0648\u06af Backend \u062f\u0631 \u062f\u0633\u062a\u0631\u0633 \u0646\u06cc\u0633\u062a. \u0647\u06cc\u0686 \u0645\u0628\u0644\u063a \u06cc\u0627 \u0647\u0632\u06cc\u0646\u0647\u200c\u0627\u06cc \u0627\u062e\u062a\u0631\u0627\u0639 \u0646\u0634\u062f\u0647 \u0627\u0633\u062a.'
          : 'Official fee schedules are not available from the Backend catalog. No amounts have been invented.',
      items: const [],
    );
  }
}
