import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pathway_comparison_repository.dart';
import '../../domain/entities/pathway_comparison.dart';

final pathwayComparisonRepositoryProvider =
    Provider<PathwayComparisonRepository>((ref) {
      return const StaticPathwayComparisonRepository();
    });

final pathwayComparisonListProvider =
    FutureProvider.family<List<PathwayComparisonItem>, String>((
      ref,
      locale,
    ) async {
      return ref
          .watch(pathwayComparisonRepositoryProvider)
          .getComparisonItems(locale: locale);
    });
