import '../domain/entities/pathway_comparison.dart';

abstract class PathwayComparisonRepository {
  Future<List<PathwayComparisonItem>> getComparisonItems({
    required String locale,
  });
}

/// Pathway comparison requires Backend-approved, source-attributed catalog rows.
/// Never invents processing times, language levels, or eligibility claims.
class StaticPathwayComparisonRepository implements PathwayComparisonRepository {
  const StaticPathwayComparisonRepository();

  @override
  Future<List<PathwayComparisonItem>> getComparisonItems({
    required String locale,
  }) async {
    // Explicit empty: official pathway attributes are not available offline.
    return const <PathwayComparisonItem>[];
  }
}
