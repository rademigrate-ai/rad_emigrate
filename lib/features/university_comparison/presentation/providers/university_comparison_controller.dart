import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/university_comparison_repository.dart';
import '../../domain/entities/university_comparison.dart';

final universityComparisonRepositoryProvider =
    Provider<UniversityComparisonRepository>((ref) {
      return const StaticUniversityComparisonRepository();
    });

class UniversityQuery {
  const UniversityQuery({this.countryFilter, required this.locale});

  final String? countryFilter;
  final String locale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UniversityQuery &&
          runtimeType == other.runtimeType &&
          countryFilter == other.countryFilter &&
          locale == other.locale;

  @override
  int get hashCode => countryFilter.hashCode ^ locale.hashCode;
}

final universityListProvider =
    FutureProvider.family<List<UniversityComparisonItem>, UniversityQuery>((
      ref,
      query,
    ) async {
      return ref
          .watch(universityComparisonRepositoryProvider)
          .getUniversities(
            countryFilter: query.countryFilter,
            locale: query.locale,
          );
    });
