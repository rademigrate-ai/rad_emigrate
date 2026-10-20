import 'dart:convert';

import '../../../core/supabase/supabase_client.dart';
import '../domain/entities/fx_rate.dart';

/// Thrown when FX quote cannot be obtained from Backend without inventing rates.
class FxQuoteUnavailableException implements Exception {
  const FxQuoteUnavailableException([this.message = 'fx_quote_unavailable']);
  final String message;
  @override
  String toString() => message;
}

abstract class FxRepository {
  Future<FxRateQuote> getQuote({String base = 'EUR', String quote = 'IRR'});
}

class SupabaseFxRepository implements FxRepository {
  final SupabaseClientService _service;

  const SupabaseFxRepository(this._service);

  @override
  Future<FxRateQuote> getQuote({
    String base = 'EUR',
    String quote = 'IRR',
  }) async {
    if (!_service.isInitialized) {
      throw const FxQuoteUnavailableException('fx_backend_not_initialized');
    }
    try {
      final response = await _service.client
          .rpc(
            'get_fx_quote',
            params: {
              'p_request': {
                'base': base.toUpperCase(),
                'quote': quote.toUpperCase(),
                'rate_basis': 'provider_reference',
                'allow_stale': true,
              },
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response == null) {
        throw const FxQuoteUnavailableException('fx_quote_empty_response');
      }
      final data = response is String ? jsonDecode(response) : response;
      if (data is! Map) {
        throw const FxQuoteUnavailableException('fx_quote_malformed_response');
      }
      final map = Map<String, dynamic>.from(data as Map);
      final payload = map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : map;
      // Never invent rates: parse only Backend-provided payload.
      return FxRateQuote.fromJson(payload);
    } on FxQuoteUnavailableException {
      rethrow;
    } catch (e) {
      throw FxQuoteUnavailableException(
        'fx_quote_unavailable: ${e.runtimeType}',
      );
    }
  }
}
