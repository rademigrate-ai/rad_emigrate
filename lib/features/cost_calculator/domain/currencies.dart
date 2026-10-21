// Supported display currencies for the cost calculator.
//
// Conversion is deliberately NOT performed client-side: an unverified FX rate
// would be an invented number. A figure published in its original currency is
// shown in that currency; totals only combine figures that already share one
// currency. Choosing a different display currency marks affected lines as
// "conversion unavailable" instead of guessing a rate.

/// A display currency the calculator can present.
class CostCurrency {
  const CostCurrency({
    required this.code,
    required this.symbol,
    required this.nameEn,
    required this.nameFa,
  });

  final String code;
  final String symbol;
  final String nameEn;
  final String nameFa;
}

/// Currencies surfaced for display. Selection never converts values.
const List<CostCurrency> kCostCurrencies = [
  CostCurrency(
    code: 'USD',
    symbol: r'$',
    nameEn: 'US Dollar',
    nameFa: 'دلار آمریکا',
  ),
  CostCurrency(code: 'EUR', symbol: '€', nameEn: 'Euro', nameFa: 'یورو'),
  CostCurrency(
    code: 'GBP',
    symbol: '£',
    nameEn: 'British Pound',
    nameFa: 'پوند بریتانیا',
  ),
  CostCurrency(
    code: 'CAD',
    symbol: 'CA\$',
    nameEn: 'Canadian Dollar',
    nameFa: 'دلار کانادا',
  ),
  CostCurrency(
    code: 'AUD',
    symbol: 'A\$',
    nameEn: 'Australian Dollar',
    nameFa: 'دلار استرالیا',
  ),
  CostCurrency(
    code: 'TRY',
    symbol: '₺',
    nameEn: 'Turkish Lira',
    nameFa: 'لیر ترکیه',
  ),
  CostCurrency(
    code: 'AED',
    symbol: 'AED',
    nameEn: 'UAE Dirham',
    nameFa: 'درهم امارات',
  ),
];

CostCurrency? costCurrencyByCode(String? code) {
  if (code == null) return null;
  final needle = code.trim().toUpperCase();
  for (final currency in kCostCurrencies) {
    if (currency.code == needle) return currency;
  }
  return null;
}
