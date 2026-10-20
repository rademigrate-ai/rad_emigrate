import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/entities/canonical_pathway_entities.dart';

abstract class CanonicalPathwayRepository {
  Future<CanonicalPathwayArticle?> getCanonicalPathway({
    required String countryCode,
    required String pathwaySlug,
  });

  Future<IndependentArticle?> getIndependentArticle({
    required String countryCode,
    required String articleSlug,
  });
}

/// Backend-only pathway articles. Never fabricates verified content or fact-check dates.
class SupabaseCanonicalPathwayRepository implements CanonicalPathwayRepository {
  final SupabaseClientService _service;

  const SupabaseCanonicalPathwayRepository(this._service);

  @override
  Future<CanonicalPathwayArticle?> getCanonicalPathway({
    required String countryCode,
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
                'locale': 'fa',
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
    required String articleSlug,
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
                  'pathway_slug': articleSlug,
                  'kind': 'related',
                },
                'locale': 'fa',
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
