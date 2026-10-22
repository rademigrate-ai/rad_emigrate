// Immigration Cost Calculator domain entities.
//
// Accurately itemizes government application fees and baseline expenses
// with clear official disclaimers. Never invents official costs.

enum ExpenseCategory {
  governmentFee,
  biometrics,
  healthInsurance,
  languageAssessment,
  settlementFunds,
}

extension ExpenseCategoryX on ExpenseCategory {
  String label(bool fa) => switch (this) {
    ExpenseCategory.governmentFee =>
      fa ? 'هزینه دولتی ویزا' : 'Government visa fee',
    ExpenseCategory.biometrics =>
      fa ? 'انگشت‌نگاری و بیومتریک' : 'Biometrics fee',
    ExpenseCategory.healthInsurance =>
      fa ? 'بیمه درمانی و سلامت' : 'Health surcharge / insurance',
    ExpenseCategory.languageAssessment =>
      fa ? 'آزمون زبان' : 'Language assessment',
    ExpenseCategory.settlementFunds =>
      fa ? 'تمکن مالی مورد نیاز' : 'Required proof of funds',
  };
}

class CostItem {
  const CostItem({
    required this.title,
    required this.amount,
    required this.currency,
    required this.category,
    this.isOptional = false,
  });

  final String title;
  final double amount;
  final String currency;
  final ExpenseCategory category;
  final bool isOptional;
}

class CostEstimateResult {
  const CostEstimateResult({
    required this.countryCode,
    required this.countryName,
    required this.pathwaySlug,
    required this.pathwayName,
    required this.items,
    required this.baseCurrency,
    required this.disclaimer,
  });

  final String countryCode;
  final String countryName;
  final String pathwaySlug;
  final String pathwayName;
  final List<CostItem> items;
  final String baseCurrency;
  final String disclaimer;

  double get totalMandatoryAmount => items
      .where(
        (item) =>
            !item.isOptional &&
            item.category != ExpenseCategory.settlementFunds,
      )
      .fold(0.0, (sum, item) => sum + item.amount);

  double get settlementFundsAmount => items
      .where((item) => item.category == ExpenseCategory.settlementFunds)
      .fold(0.0, (sum, item) => sum + item.amount);
}
