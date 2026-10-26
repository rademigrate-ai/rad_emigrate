import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/entities/canonical_pathway_entities.dart';

abstract class CanonicalPathwayRepository {
  Future<CanonicalPathwayArticle?> getCanonicalPathway({
    required String countryCode,
    String locale = 'fa',
    required String pathwaySlug,
  });

  Future<IndependentArticle?> getIndependentArticle({
    required String countryCode,
    String locale = 'fa',
    required String articleSlug,
  });
}

/// Backend-only pathway articles. Never fabricates verified content or fact-check dates.
class SupabaseCanonicalPathwayRepository implements CanonicalPathwayRepository {
  final SupabaseClientService _service;

  const SupabaseCanonicalPathwayRepository(this._service);

  /// Published main and related articles share the canonical UUID selector.
  Future<CanonicalPathwayArticle?> getArticleById(
    String articleId, {
    String locale = 'fa',
  }) async {
    if (!_service.isInitialized) return null;
    final response = await _service.client.rpc(
      'get_visa_article',
      params: {
        'p_request': {
          'selector': {'article_id': articleId},
          'locale': locale,
        },
      },
    );
    if (response is! Map) throw const FormatException('article_unavailable');
    return CanonicalPathwayArticle.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<CanonicalPathwayArticle?> getCanonicalPathway({
    required String countryCode,
    String locale = 'fa',
    required String pathwaySlug,
  }) async {
    if (!_service.isInitialized) return null;
    try {
      final response = await _service.client
          .rpc(
            'get_visa_article',
            params: {
              'p_request': {
                'selector': {
                  'country_code': countryCode.toUpperCase(),
                  'pathway_slug': pathwaySlug,
                  'kind': 'main',
                },
                'locale': locale,
              },
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response == null) return null;
      final data = response is String ? jsonDecode(response) : response;
      if (data is Map<String, dynamic>) {
        return CanonicalPathwayArticle.fromJson(data);
      }
      if (data is Map) {
        return CanonicalPathwayArticle.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      return null;
    } catch (_) {
      // Unavailable / denied / malformed must not become published content.
      return null;
    }
  }

  @override
  Future<IndependentArticle?> getIndependentArticle({
    required String countryCode,
    String locale = 'fa',
    required String articleSlug,
  }) async {
    if (!_service.isInitialized) return null;
    try {
      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(articleSlug);
      final resolved = isUuid
          ? {
              'data': {'article_id': articleSlug},
            }
          : await _service.client
                .rpc(
                  'resolve_editorial_article_slug',
                  params: {
                    'p_country_code': countryCode,
                    'p_slug': articleSlug,
                    'p_locale': locale,
                  },
                )
                .timeout(const Duration(seconds: 20));
      if (resolved is! Map ||
          resolved['data'] is! Map ||
          resolved['data']['article_id'] is! String) {
        throw const FormatException('invalid_article_identity');
      }
      final response = await _service.client
          .rpc(
            'get_visa_article',
            params: {
              'p_request': {
                'selector': {'article_id': resolved['data']['article_id']},
                'locale': locale,
              },
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response == null) return null;
      final data = response is String ? jsonDecode(response) : response;
      if (data is Map<String, dynamic>) {
        return IndependentArticle.fromJson(data);
      }
      if (data is Map) {
        return IndependentArticle.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final canonicalPathwayRepositoryProvider = Provider<CanonicalPathwayRepository>(
  (ref) {
    return SupabaseCanonicalPathwayRepository(
      ref.watch(supabaseClientServiceProvider),
    );
  },
);

typedef PublishedArticleKey = ({
  String articleId,
  String requestedLocale,
  String resolvedLocale,
});

final publishedVisaArticleProvider = FutureProvider.autoDispose
    .family<CanonicalPathwayArticle?, PublishedArticleKey>((ref, key) {
      return SupabaseCanonicalPathwayRepository(
        ref.watch(supabaseClientServiceProvider),
      ).getArticleById(key.articleId, locale: key.resolvedLocale);
    });
