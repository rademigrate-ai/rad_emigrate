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
  final String? referenceRateDecimal;
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
    this.referenceRateDecimal,
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

  /// Parse only complete Backend payloads. Missing required fields throw —
  /// never invent rates, providers, currencies, or freshness timestamps.
  factory FxRateQuote.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final base = (json['base'] ?? json['base_currency'])
        ?.toString()
        .toUpperCase();
    final quote = (json['quote'] ?? json['quote_currency'])
        ?.toString()
        .toUpperCase();
    final rateRaw = json['rate'] ?? json['reference_rate_irr'];
    final rate = rateRaw is num
        ? rateRaw.toDouble()
        : double.tryParse(rateRaw?.toString() ?? '');
    final obsRaw = json['observation_date']?.toString();
    final fetchedRaw =
        json['fetched_at']?.toString() ?? json['timestamp']?.toString();

    if (id == null ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id) ||
        base == null ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(base) ||
        quote == null ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(quote) ||
        rate == null ||
        rateRaw is! String ||
        !RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]+)?$').hasMatch(rateRaw) ||
        !rate.isFinite ||
        rate <= 0 ||
        obsRaw == null ||
        obsRaw.isEmpty ||
        fetchedRaw == null ||
        fetchedRaw.isEmpty) {
      throw FormatException('fx_quote_malformed_or_incomplete');
    }

    final source = Uri.tryParse(json['source_url']?.toString() ?? '');
    if (!{'frankfurter', 'fawazahmed0'}.contains(json['provider']) ||
        !FreshnessState.values.any((v) => v.name == json['freshness_state']) ||
        json['rate_basis'] != 'provider_reference' ||
        source?.scheme != 'https' ||
        source!.host.isEmpty ||
        source.userInfo.isNotEmpty) {
      throw const FormatException('fx_quote_invalid_provenance');
    }
    final observationDate = DateTime.parse(obsRaw);
    final fetchedAt = DateTime.parse(fetchedRaw);
    final provider = json['provider'] == 'fawazahmed0'
        ? FxProvider.fawazahmed0
        : FxProvider.frankfurter;
    final freshness = FreshnessState.values.firstWhere(
      (e) => e.name == json['freshness_state'],
      orElse: () => FreshnessState.unknown,
    );

    return FxRateQuote(
      id: id,
      provider: provider,
      baseCurrency: base,
      quoteCurrency: quote,
      referenceRate: rate,
      referenceRateDecimal: rateRaw,
      rateBasis: RateBasis.providerReference,
      observationDate: observationDate,
      fetchedAt: fetchedAt,
      freshnessState: freshness,
      sourceUrl: json['source_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider.name,
    'base': baseCurrency,
    'quote': quoteCurrency,
    'rate': referenceRateDecimal ?? referenceRate.toString(),
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
