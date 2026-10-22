import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/visa/data/fx_repository.dart';
import 'package:rad_emigrate/features/visa/domain/entities/fx_rate.dart';

void main() {
  group('FX Rate & Currency Domain Tests', () {
    test(
      'FxRateQuote strictly enforces providerReference and approved providers',
      () {
        final quote = FxRateQuote(
          id: 'test-eur-irr',
          provider: FxProvider.frankfurter,
          baseCurrency: 'EUR',
          quoteCurrency: 'IRR',
          referenceRate: 485000.0,
          rateBasis: RateBasis.providerReference,
          observationDate: DateTime.now(),
          fetchedAt: DateTime.now(),
          freshnessState: FreshnessState.fresh,
          sourceUrl: 'https://api.frankfurter.dev/v1/latest',
        );

        expect(quote.provider, FxProvider.frankfurter);
        expect(quote.rateBasis, RateBasis.providerReference);
        expect(quote.provider.displayName, 'Frankfurter (ECB Reference)');
      },
    );

    test('CurrencyConversion accurately computes Rial and arithmetic Toman (IRR / 10)', () {
      final quote = FxRateQuote(
        id: 'test-eur-irr',
        provider: FxProvider.frankfurter,
        baseCurrency: 'EUR',
        quoteCurrency: 'IRR',
        referenceRate: 500000.0,
        rateBasis: RateBasis.providerReference,
        observationDate: DateTime.now(),
        fetchedAt: DateTime.now(),
        freshnessState: FreshnessState.fresh,
        sourceUrl: 'https://api.frankfurter.dev/v1/latest',
      );

      final conversion = quote.convert(1027.0);

      // 1,027 * 500,000 = 513,500,000 IRR
      expect(conversion.amountIrr, 513500000.0);
      // Toman = 513,500,000 / 10 = 51,350,000 Toman
      expect(conversion.amountToman, 51350000.0);
      expect(conversion.formatToman(), '51350000 تومان');
      expect(conversion.formatRial(), '513500000 ریال');
    });

    test('SupabaseFxRepository reports unavailable instead of inventing an offline quote', () async {
      final repo = SupabaseFxRepository(SupabaseClientService.instance);
      expect(SupabaseClientService.instance.isInitialized, isFalse);
      await expectLater(
        repo.getQuote(base: 'EUR', quote: 'IRR'),
        throwsA(isA<FxQuoteUnavailableException>()),
      );
    });
  });
}
