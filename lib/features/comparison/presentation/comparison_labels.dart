// Comparison presentation labels.
// Bilingual (FA/EN) copy following the approved feature-local labels pattern.

class ComparisonLabels {
  const ComparisonLabels(this.language);

  final String language;

  bool get fa => language == 'fa';

  String get title => fa ? 'مقایسه مسیرها' : 'Compare pathways';

  /// Compact dashboard-tile label (dashboard quick actions).
  String get shortTitle => fa ? 'مقایسه' : 'Compare';

  String get intro => fa
      ? 'چند مقصد و مسیر را کنار هم مقایسه کنید. فقط داده‌های منتشرشده و دارای منبع نمایش داده می‌شود.'
      : 'Compare several destinations and pathways side by side. Only published, sourced data is shown.';

  String get selectPrompt => fa
      ? 'برای مقایسه، دو تا سه مسیر انتخاب کنید.'
      : 'Select two or three pathways to compare.';

  String get selectionFull => fa
      ? 'حداکثر سه مسیر قابل مقایسه است.'
      : 'Up to three pathways can be compared.';

  String get compareAction => fa ? 'مقایسه' : 'Compare';

  String get clearAction => fa ? 'پاک کردن' : 'Clear';

  String get countryLabel => fa ? 'کشور' : 'Country';

  String get pathwayLabel => fa ? 'مسیر' : 'Pathway';

  String get categoryLabel => fa ? 'دسته‌بندی' : 'Category';

  String get processingTimeLabel => fa ? 'مدت بررسی' : 'Processing time';

  String get feesLabel => fa ? 'هزینه‌ها' : 'Fees';

  String get requirementsLabel => fa ? 'الزامات' : 'Requirements';

  String get sourceLabel => fa ? 'منبع رسمی' : 'Authoritative source';

  String get retrievedAt => fa ? 'تاریخ دریافت' : 'Retrieved';

  String get notPublished => fa ? 'منتشر نشده' : 'Not published';

  String get proseHint => fa
      ? 'منبع به صورت متن منتشر کرده است.'
      : 'The source published this as prose.';

  String get emptyCatalog => fa
      ? 'هیچ مسیر منتشرشده‌ای برای مقایسه یافت نشد.'
      : 'No published pathway is available to compare.';

  String get genericError => fa
      ? 'دریافت داده مقایسه با خطا مواجه شد.'
      : 'Loading comparison data failed.';

  String get signInPrompt => fa
      ? 'برای مشاهدهٔ کاتالوگ تأییدشده وارد شوید.'
      : 'Sign in to view the verified catalog.';

  String get disclaimer => fa
      ? 'مقایسه فقط بر اساس انتشارات رسمی انجام می‌شود و توصیهٔ حقوقی یا تضمین پذیرش نیست.'
      : 'Comparison reflects official publications only; it is not legal advice or an admission guarantee.';
}
