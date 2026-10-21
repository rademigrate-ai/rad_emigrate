import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/entities/search_entities.dart';

abstract class VisaSearchRepository {
  Future<SmartSearchResult> search({
    required String query,
    String locale = 'fa',
    String? countryFilter,
    String? categoryFilter,
  });
}

/// Backend-only smart search. Never fabricates verified hits or fact-check dates.
class SupabaseVisaSearchRepository implements VisaSearchRepository {
  final SupabaseClientService _service;

  const SupabaseVisaSearchRepository(this._service);

  @override
  Future<SmartSearchResult> search({
    required String query,
    String locale = 'fa',
    String? countryFilter,
    String? categoryFilter,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return SmartSearchResult.empty(trimmed);
    }
    if (!_service.isInitialized) {
      return SmartSearchResult.empty(trimmed);
    }
    try {
      final response = await _service.client
          .rpc(
            'search_visa_articles',
            params: {
              'p_request': {
                'query': trimmed,
                'locale': locale,
                'country_codes':
                    countryFilter != null && countryFilter.isNotEmpty
                    ? [countryFilter.toUpperCase()]
                    : <String>[],
                'pathway_slugs':
                    categoryFilter != null && categoryFilter.isNotEmpty
                    ? [categoryFilter]
                    : <String>[],
                'article_kind': null,
                'allow_locale_fallback': true,
                'cursor': null,
                'limit': 20,
              },
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response == null) {
        return SmartSearchResult.empty(trimmed);
      }
      final data = response is String ? jsonDecode(response) : response;
      if (data is Map<String, dynamic>) {
        return SmartSearchResult.fromJson(
          data,
          query: trimmed,
          requestedLocale: locale,
        );
      }
      if (data is Map) {
        return SmartSearchResult.fromJson(
          Map<String, dynamic>.from(data),
          query: trimmed,
          requestedLocale: locale,
        );
      }
      return SmartSearchResult.empty(trimmed);
    } catch (_) {
      // Unavailable / denied / malformed must not become verified search hits.
      return SmartSearchResult.empty(trimmed);
    }
  }
}

final visaSearchRepositoryProvider = Provider<VisaSearchRepository>((ref) {
  return SupabaseVisaSearchRepository(ref.watch(supabaseClientServiceProvider));
});
