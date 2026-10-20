import '../domain/entities/university_comparison.dart';

abstract class UniversityComparisonRepository {
  Future<List<UniversityComparisonItem>> getUniversities({
    required String locale,
    String? countryFilter,
  });
}

/// University rows require Backend-approved institutional data with provenance.
/// Never invents rankings, tuition, or partnerships.
class StaticUniversityComparisonRepository
    implements UniversityComparisonRepository {
  const StaticUniversityComparisonRepository();

  @override
  Future<List<UniversityComparisonItem>> getUniversities({
    required String locale,
    String? countryFilter,
  }) async {
    return const <UniversityComparisonItem>[];
  }
}
