import 'package:flutter/foundation.dart';

/// Approved foreign exchange rate providers.
/// Frankfurter provides ECB daily reference rates; Fawazahmed0 serves as fallback mirror.
enum FxProvider { frankfurter, fawazahmed0 }

/// The economic/contract basis of the exchange rate.
/// Strictly provider_reference; Iranian open-market rates are unapproved in production.
enum RateBasis { providerReference }

/// The freshness condition of the exchange rate.
enum FreshnessState { fresh, stale, unknown }

@immutable
class FxRateQuote {
  final String id;
  final FxProvider provider;
  final String baseCurrency; // e.g. EUR, USD, CAD
  final String quoteCurrency; // e.g. IRR
  final double referenceRate; // Decimal reference rate
  final RateBasis rateBasis;
  final DateTime observationDate;
  final DateTime fetchedAt;
  final FreshnessState freshnessState;
  final String sourceUrl;

  const FxRateQuote({
    required this.id,
    required this.provider,
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.referenceRate,
    this.rateBasis = RateBasis.providerReference,
    required this.observationDate,
    required this.fetchedAt,
    required this.freshnessState,
    required this.sourceUrl,
  });

  /// Client-side arithmetic helper: 1 Toman = 10 Rials.
  /// Decoupled from the provider exchange-rate basis.
  double get referenceRateToman => referenceRate / 10.0;

  bool get isStale => freshnessState == FreshnessState.stale;

  factory FxRateQuote.fromJson(Map<String, dynamic> json) => FxRateQuote(
    id:
        json['id'] as String? ??
        'quote-${DateTime.now().millisecondsSinceEpoch}',
    provider: json['provider'] == 'fawazahmed0'
        ? FxProvider.fawazahmed0
        : FxProvider.frankfurter,
    baseCurrency:
        json['base'] as String? ?? json['base_currency'] as String? ?? 'EUR',
    quoteCurrency:
        json['quote'] as String? ?? json['quote_currency'] as String? ?? 'IRR',
    referenceRate:
        double.tryParse(json['rate']?.toString() ?? '0') ??
        (json['reference_rate_irr'] as num?)?.toDouble() ??
        0.0,
    rateBasis: RateBasis.providerReference,
    observationDate: json['observation_date'] != null
        ? DateTime.parse(json['observation_date'] as String)
        : DateTime.now(),
    fetchedAt: json['fetched_at'] != null
        ? DateTime.parse(json['fetched_at'] as String)
        : (json['timestamp'] != null
              ? DateTime.parse(json['timestamp'] as String)
              : DateTime.now()),
    freshnessState: FreshnessState.values.firstWhere(
      (e) => e.name == json['freshness_state'],
      orElse: () => FreshnessState.fresh,
    ),
    sourceUrl: json['source_url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider.name,
    'base': baseCurrency,
    'quote': quoteCurrency,
    'rate': referenceRate.toStringAsFixed(2),
    'rate_basis': 'provider_reference',
    'observation_date': observationDate.toIso8601String().split('T').first,
    'fetched_at': fetchedAt.toIso8601String(),
    'freshness_state': freshnessState.name,
    'source_url': sourceUrl,
    'toman_reference_rate': referenceRateToman.toStringAsFixed(2),
  };

  /// Computes equivalent Rial and Toman values strictly on provider reference rate basis
  CurrencyConversion convert(double foreignAmount) {
    final totalRial = foreignAmount * referenceRate;
    final totalToman = totalRial / 10.0;
    return CurrencyConversion(
      foreignAmount: foreignAmount,
      foreignCurrency: baseCurrency,
      amountIrr: totalRial,
      amountToman: totalToman,
      referenceRateUsed: referenceRate,
      provider: provider,
      rateBasis: rateBasis,
      observationDate: observationDate,
    );
  }
}

@immutable
class CurrencyConversion {
  final double foreignAmount;
  final String foreignCurrency;
  final double amountIrr;
  final double amountToman;
  final double referenceRateUsed;
  final FxProvider provider;
  final RateBasis rateBasis;
  final DateTime observationDate;

  const CurrencyConversion({
    required this.foreignAmount,
    required this.foreignCurrency,
    required this.amountIrr,
    required this.amountToman,
    required this.referenceRateUsed,
    required this.provider,
    required this.rateBasis,
    required this.observationDate,
  });

  String formatToman() {
    final rounded = amountToman.round();
    return '$rounded تومان';
  }

  String formatRial() {
    final rounded = amountIrr.round();
    return '$rounded ریال';
  }
}

extension FxProviderExtension on FxProvider {
  String get displayName => switch (this) {
    FxProvider.frankfurter => 'Frankfurter (ECB Reference)',
    FxProvider.fawazahmed0 => 'Fawazahmed0 (Fallback Mirror)',
  };
}
