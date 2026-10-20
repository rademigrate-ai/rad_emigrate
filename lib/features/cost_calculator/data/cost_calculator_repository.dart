import '../domain/entities/cost_estimate.dart';

abstract class CostCalculatorRepository {
  Future<CostEstimateResult> calculatePathwayCosts({
    required String countryCode,
    required String pathwaySlug,
    required int applicantsCount,
    required String locale,
  });
}

class StaticCostCalculatorRepository implements CostCalculatorRepository {
  const StaticCostCalculatorRepository();

  @override
  Future<CostEstimateResult> calculatePathwayCosts({
    required String countryCode,
    required String pathwaySlug,
    required int applicantsCount,
    required String locale,
  }) async {
    final isFa = locale == 'fa';

    // Official verified baseline fee schedules for canonical pathways
    if (countryCode.toUpperCase() == 'DE' && pathwaySlug == 'chancenkarte') {
      return CostEstimateResult(
        countryCode: 'DE',
        countryName: isFa ? 'آلمان' : 'Germany',
        pathwaySlug: 'chancenkarte',
        pathwayName: isFa
            ? 'کارت شانس (Chancenkarte)'
            : 'Opportunity Card (Chancenkarte)',
        baseCurrency: 'EUR',
        disclaimer: isFa
            ? 'هزینه‌های دولتی بر اساس تعرفه رسمی سفارت آلمان است و هزینه‌های تمکن مالی بر اساس حداقل مسدودی سالانه محاسبه شده است.'
            : 'Government fees are based on official German mission schedules. Proof of funds reflects required blocked account minimums.',
        items: [
          CostItem(
            title: isFa
                ? 'تعرفه صدور روادید کارت شانس'
                : 'Chancenkarte visa application fee',
            amount: 75.0 * applicantsCount,
            currency: 'EUR',
            category: ExpenseCategory.governmentFee,
          ),
          CostItem(
            title: isFa
                ? 'بیمه درمانی ورودی (تخمینی ۶ ماه)'
                : 'Travel health insurance (est. 6 months)',
            amount: 250.0 * applicantsCount,
            currency: 'EUR',
            category: ExpenseCategory.healthInsurance,
            isOptional: true,
          ),
          CostItem(
            title: isFa
                ? 'حساب مسدودی تمکن مالی سالانه (Sperrkonto)'
                : 'Annual blocked account funds (Sperrkonto)',
            amount: 12324.0,
            currency: 'EUR',
            category: ExpenseCategory.settlementFunds,
          ),
        ],
      );
    }

    if (countryCode.toUpperCase() == 'CA' && pathwaySlug == 'express-entry') {
      return CostEstimateResult(
        countryCode: 'CA',
        countryName: isFa ? 'کانادا' : 'Canada',
        pathwaySlug: 'express-entry',
        pathwayName: isFa ? 'اکسپرس اینتری (Express Entry)' : 'Express Entry',
        baseCurrency: 'CAD',
        disclaimer: isFa
            ? 'هزینه‌ها بر اساس تعرفه رسمی اداره مهاجرت کانادا (IRCC) در سال ۲۰۲۶ محاسبه شده است.'
            : 'Fees are calculated in accordance with official IRCC fee schedules for 2026.',
        items: [
          CostItem(
            title: isFa
                ? 'هزینه بررسی پرونده (Processing Fee)'
                : 'Application processing fee',
            amount: 950.0 * applicantsCount,
            currency: 'CAD',
            category: ExpenseCategory.governmentFee,
          ),
          CostItem(
            title: isFa
                ? 'حق اقامت دائم (Right of PR Fee)'
                : 'Right of Permanent Residence Fee (RPRF)',
            amount: 575.0 * applicantsCount,
            currency: 'CAD',
            category: ExpenseCategory.governmentFee,
          ),
          CostItem(
            title: isFa ? 'بیومتریک و انگشت‌نگاری' : 'Biometrics fee',
            amount: 85.0 * applicantsCount,
            currency: 'CAD',
            category: ExpenseCategory.biometrics,
          ),
          CostItem(
            title: isFa
                ? 'حداقل تمکن مالی قانونی (۱ نفره)'
                : 'Settlement funds (single applicant)',
            amount: 14690.0,
            currency: 'CAD',
            category: ExpenseCategory.settlementFunds,
          ),
        ],
      );
    }

    // Generic fallback with explicit estimate notice
    return CostEstimateResult(
      countryCode: countryCode,
      countryName: countryCode.toUpperCase(),
      pathwaySlug: pathwaySlug,
      pathwayName: pathwaySlug,
      baseCurrency: 'USD',
      disclaimer: isFa
          ? 'تعرفه رسمی این مسیر به صورت برخط تایید نشده است. ارقام تخمینی کلی می‌باشند.'
          : 'Official fees for this pathway are not verified online. Figures are general estimates.',
      items: [
        CostItem(
          title: isFa ? 'هزینه پایه بررسی ویزا' : 'Base visa processing fee',
          amount: 350.0 * applicantsCount,
          currency: 'USD',
          category: ExpenseCategory.governmentFee,
        ),
      ],
    );
  }
}
