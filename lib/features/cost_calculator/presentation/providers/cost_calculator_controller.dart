import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cost_calculator_repository.dart';
import '../../domain/entities/cost_estimate.dart';

final costCalculatorRepositoryProvider = Provider<CostCalculatorRepository>((
  ref,
) {
  return const StaticCostCalculatorRepository();
});

class CostCalculatorQuery {
  const CostCalculatorQuery({
    required this.countryCode,
    required this.pathwaySlug,
    this.applicantsCount = 1,
    this.locale = 'fa',
  });

  final String countryCode;
  final String pathwaySlug;
  final int applicantsCount;
  final String locale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CostCalculatorQuery &&
          runtimeType == other.runtimeType &&
          countryCode == other.countryCode &&
          pathwaySlug == other.pathwaySlug &&
          applicantsCount == other.applicantsCount &&
          locale == other.locale;

  @override
  int get hashCode =>
      countryCode.hashCode ^
      pathwaySlug.hashCode ^
      applicantsCount.hashCode ^
      locale.hashCode;
}

final costEstimateProvider =
    FutureProvider.family<CostEstimateResult, CostCalculatorQuery>((
      ref,
      query,
    ) async {
      return ref
          .watch(costCalculatorRepositoryProvider)
          .calculatePathwayCosts(
            countryCode: query.countryCode,
            pathwaySlug: query.pathwaySlug,
            applicantsCount: query.applicantsCount,
            locale: query.locale,
          );
    });
