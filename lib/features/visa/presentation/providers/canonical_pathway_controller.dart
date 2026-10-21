import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/canonical_pathway_repository.dart';
import '../../domain/entities/canonical_pathway_entities.dart';

typedef PathwayQueryKey = ({
  String countryCode,
  String pathwaySlug,
  String locale,
});
typedef ArticleQueryKey = ({
  String countryCode,
  String articleSlug,
  String locale,
});

final canonicalPathwayProvider =
    FutureProvider.family<CanonicalPathwayArticle?, PathwayQueryKey>((
      ref,
      key,
    ) async {
      final repo = ref.watch(canonicalPathwayRepositoryProvider);
      return repo.getCanonicalPathway(
        countryCode: key.countryCode,
        locale: key.locale,
        pathwaySlug: key.pathwaySlug,
      );
    });

final independentArticleProvider =
    FutureProvider.family<IndependentArticle?, ArticleQueryKey>((
      ref,
      key,
    ) async {
      final repo = ref.watch(canonicalPathwayRepositoryProvider);
      return repo.getIndependentArticle(
        countryCode: key.countryCode,
        locale: key.locale,
        articleSlug: key.articleSlug,
      );
    });
