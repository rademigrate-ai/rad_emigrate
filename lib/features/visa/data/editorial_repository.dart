import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

typedef EditorialArticleKey = ({String id, String locale, bool preview});
typedef CountryContentKey = ({String country, String locale, bool preview});

Map<String, dynamic> editorialData(dynamic response) {
  if (response is! Map || response['data'] is! Map) {
    throw const FormatException('invalid_editorial_response');
  }
  return Map<String, dynamic>.from(response['data'] as Map);
}

List<Map<String, dynamic>> editorialRows(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

Future<Map<String, dynamic>> _withReferences(
  SupabaseClient client,
  Map<String, dynamic> article,
  EditorialArticleKey key,
) async {
  try {
    final refs = editorialData(
      await client
          .rpc(
            'get_editorial_reference_links',
            params: {
              'p_article_id': key.id,
              'p_locale': key.locale,
              'p_preview': key.preview,
            },
          )
          .timeout(const Duration(seconds: 20)),
    );
    if (refs['revision_id'] != article['revision_id'] ||
        refs['links'] is! List ||
        !{'complete', 'not_captured'}.contains(refs['capture_status'])) {
      throw const FormatException('reference_revision_or_shape_mismatch');
    }
    return {
      ...article,
      'reference_links': refs['links'],
      'references_capture_status': refs['capture_status'],
    };
  } on PostgrestException catch (error) {
    if (!{'PGRST202', '42883'}.contains(error.code)) rethrow;
    return {
      ...article,
      'reference_links': const [],
      'references_capture_status': 'unavailable',
    };
  }
}

final editorialArticleProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, EditorialArticleKey>((ref, key) async {
      // Preview state must expire on every account/session change. No local
      // persistent cache or fallback from a public request to a private RPC.
      ref.watch(supabaseAuthUserIdProvider);
      final service = ref.watch(supabaseClientServiceProvider);
      if (!service.isInitialized) throw StateError('backend_unavailable');
      try {
        final response = await service.client
            .rpc(
              'get_editorial_article',
              params: {
                'p_article_id': key.id,
                'p_locale': key.locale,
                'p_preview': key.preview,
              },
            )
            .timeout(const Duration(seconds: 20));
        return await _withReferences(
          service.client,
          editorialData(response),
          key,
        );
      } on PostgrestException catch (error) {
        if (key.preview || !{'PGRST202', '42883'}.contains(error.code)) rethrow;
        final response = await service.client
            .rpc(
              'get_visa_article',
              params: {
                'p_request': {
                  'selector': {'article_id': key.id},
                  'locale': key.locale,
                },
              },
            )
            .timeout(const Duration(seconds: 20));
        return await _withReferences(
          service.client,
          editorialData(response),
          key,
        );
      }
    });

final countryVisaContentProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, CountryContentKey>((ref, key) async {
      ref.watch(supabaseAuthUserIdProvider);
      final service = ref.watch(supabaseClientServiceProvider);
      if (!service.isInitialized) throw StateError('backend_unavailable');
      return editorialData(
        await service.client
            .rpc(
              'list_country_visa_content',
              params: {
                'p_country_code': key.country,
                'p_locale': key.locale,
                'p_preview': key.preview,
              },
            )
            .timeout(const Duration(seconds: 20)),
      );
    });

final visaContentCountriesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, locale) async {
      ref.watch(supabaseAuthUserIdProvider);
      final service = ref.watch(supabaseClientServiceProvider);
      if (!service.isInitialized) throw StateError('backend_unavailable');
      return editorialRows(
        editorialData(
          await service.client
              .rpc(
                'list_visa_content_countries',
                params: {'p_locale': locale, 'p_preview': false},
              )
              .timeout(const Duration(seconds: 20)),
        )['items'],
      );
    });
