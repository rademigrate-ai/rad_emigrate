import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/rad_contract.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/entities/search_entities.dart';

class VisaSearchException implements Exception {
  const VisaSearchException(this.code);
  final String code;
  @override
  String toString() => 'VisaSearchException($code)';
}

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
      throw const VisaSearchException('unavailable');
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

      final data = response is String ? jsonDecode(response) : response;
      requireRadContract('search_visa_articles_response', data);
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
      throw const VisaSearchException('malformed');
    } on VisaSearchException {
      rethrow;
    } on FormatException {
      throw const VisaSearchException('malformed');
    } catch (_) {
      // The controller already exposes an explicit localized error state.
      // Unavailable / denied must not masquerade as a successful empty search.
      throw const VisaSearchException('unavailable');
    }
  }
}

final visaSearchRepositoryProvider = Provider<VisaSearchRepository>((ref) {
  return SupabaseVisaSearchRepository(ref.watch(supabaseClientServiceProvider));
});
