// Cost calculator presentation labels.
// Bilingual (FA/EN) copy following the approved feature-local labels pattern.

class CostCalculatorLabels {
  const CostCalculatorLabels(this.language);

  final String language;

  bool get fa => language == 'fa';

  String get title => fa ? 'هزینه‌های مهاجرت' : 'Immigration costs';

  String get intro => fa
      ? 'مبالغ از متن کاتالوگ استخراج می‌شوند؛ تأیید رسمی در سطح هر مبلغ موجود نیست. این محاسبه شامل همه هزینه‌های مهاجرت نیست.'
      : 'Figures are parsed from catalog text without field-level official verification. Unlisted immigration costs are excluded.';

  String get selectPathway => fa ? 'انتخاب مسیر' : 'Select a pathway';

  String get pathwayHint => fa
      ? 'برای دیدن توضیح هزینه‌ها، یک مقصد و مسیر انتخاب کنید.'
      : 'Choose a destination and pathway to see its cost breakdown.';

  String get breakdownTitle => fa ? 'جزئیات هزینه‌ها' : 'Cost breakdown';

  String get totalLabel =>
      fa ? 'جمع مبالغ قابل استخراج (ناقص)' : 'Parsed fee subtotal (incomplete)';

  String get currencyLabel => fa ? 'ارز نمایشی' : 'Display currency';

  String get currencyNoConvertNote => fa
      ? 'تبدیل ارز انجام نمی‌شود؛ مبلغ به همان ارزی که منبع منتشر کرده نمایش داده می‌شود.'
      : 'No currency conversion is performed; amounts appear in the currency the source published.';

  String get governmentFees =>
      fa ? 'هزینه‌های دولتی و درخواست' : 'Government & application fees';

  String get processingTime =>
      fa ? 'مدت بررسی منتشرشده' : 'Published processing time';

  String get sourceLabel => fa ? 'منبع کاتالوگ' : 'Catalog source';

  String get retrievedAt => fa ? 'تاریخ دریافت' : 'Retrieved';

  String get notPublished => fa
      ? 'مبلغ قابل استخراج در کاتالوگ موجود نیست.'
      : 'No parseable figure is available in the catalog.';

  String get notPublishedField => fa ? 'منتشر نشده' : 'Not published';

  String get textOnlyNote => fa
      ? 'منبع متن منتشر کرده اما عدد قطعی ندارد؛ متن اصلی در ادامه آمده است.'
      : 'The source published prose, not an exact figure; the original wording is shown below.';

  String get figureFromSource => fa
      ? 'این عدد از متن کاتالوگ استخراج شده؛ تأیید رسمی مبلغ احراز نشده است.'
      : 'Parsed from catalog text; official verification of this amount is unavailable.';

  String get noVerifiedFigure => fa
      ? 'هیچ رقم قابل استخراجی برای جمع‌بندی در دسترس نیست.'
      : 'No parseable figure is available to subtotal.';

  String get mixedCurrencies => fa
      ? 'اقلام با ارزهای متفاوت منتشر شده‌اند و نرخ تبدیل معتبری وجود ندارد.'
      : 'Line items are published in different currencies and no trusted conversion rate exists.';

  String get genericError => fa
      ? 'دریافت اطلاعات هزینه‌ها با خطا مواجه شد.'
      : 'Loading cost data failed.';

  String get signInPrompt =>
      fa ? 'برای مشاهدهٔ کاتالوگ وارد شوید.' : 'Sign in to view the catalog.';

  String get emptyCatalog => fa
      ? 'هیچ مسیر منتشرشده‌ای برای محاسبهٔ هزینه یافت نشد.'
      : 'No published pathway is available for cost estimation.';
}
