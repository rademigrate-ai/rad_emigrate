import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/canonical_pathway_repository.dart';
import '../../domain/entities/canonical_pathway_entities.dart';

typedef PathwayQueryKey = ({String countryCode, String pathwaySlug});
typedef ArticleQueryKey = ({String countryCode, String articleSlug});

final canonicalPathwayProvider =
    FutureProvider.family<CanonicalPathwayArticle?, PathwayQueryKey>((
      ref,
      key,
    ) async {
      final repo = ref.watch(canonicalPathwayRepositoryProvider);
      return repo.getCanonicalPathway(
        countryCode: key.countryCode,
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
        articleSlug: key.articleSlug,
      );
    });
