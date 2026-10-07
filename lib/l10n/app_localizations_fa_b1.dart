import 'app_localizations.dart';

mixin AppLocalizationsFaB1 on AppLocalizations {
  @override
  String get adminRestricted => 'این مسیر فقط برای مدیران راد است.';
  @override
  String get superAdmin => 'مدیر ارشد';
  @override
  String get operationalOverview => 'نمای عملیاتی';
  @override
  String get researchJobs => 'کارهای پژوهشی';
  @override
  String get aiRequests => 'درخواست‌های هوش مصنوعی';
  @override
  String get documentJobs => 'کارهای مدرک';
  @override
  String get openTasks => 'کارهای باز';
  @override
  String get auditEvents => 'رویدادهای ممیزی';
  @override
  String get serverEnforcedAccess => 'دسترسی سمت سرور';
  @override
  String get serverEnforcedAccessBody =>
      'دسترسی‌ها با RLS و ممیزی محافظت می‌شوند.';
  @override
  String get visaPathways => 'مسیرهای ویزا و مهاجرت';
  @override
  String get loadingCatalogue => 'بارگذاری فهرست…';
  @override
  String get catalogueUnavailable => 'فهرست در دسترس نیست.';
  @override
  String get findPathway => 'یافتن مسیر مرتبط';
  @override
  String get catalogueDisclaimer =>
      'فقط محتوای منتشرشده و دارای منبع نمایش داده می‌شود.';
  @override
  String get searchProgrammes => 'جستجوی برنامه‌ها';
  @override
  String get allDestinations => 'همه مقاصد';
  @override
  String get allServices => 'همه خدمات';
  @override
  String get noProgrammeFound => 'برنامه‌ای یافت نشد';
  @override
  String get tryChangingFilters => 'جستجو یا فیلتر را تغییر دهید.';
  @override
  String get publishedTimeline => 'زمان‌بندی منتشرشده';
  @override
  String get publishedFee => 'هزینه منتشرشده';
  @override
  String get publishedRequirements => 'الزامات منتشرشده';
  @override
  String get structuredDetailsPending => 'جزئیات ساختاری در انتظار بررسی است';
  @override
  String get structuredDetailsPendingBody =>
      'هنوز الزامات یا گام‌های تأییدشده‌ای منتشر نشده است.';
  @override
  String get source => 'منبع';
  @override
  String get visaDisclaimer =>
      'این اطلاعات تضمین نتیجه نیست و جایگزین قوانین رسمی نیست.';
  @override
  String get feedTitle => 'به‌روزرسانی‌های راد';
  @override
  String get loadingUpdates => 'بارگذاری به‌روزرسانی‌ها…';
  @override
  String get updatesLoadFailed => 'بارگذاری به‌روزرسانی‌ها ممکن نشد.';
  @override
  String get noReviewedUpdates =>
      'هنوز به‌روزرسانی بررسی‌شده‌ای منتشر نشده است.';
  @override
  String get bookmark => 'نشان‌گذاری';
  @override
  String get removeBookmark => 'حذف نشان';
  @override
  String get backToApplications => 'بازگشت به درخواست‌ها';
  @override
  String get couldNotCreateDraft => 'ایجاد پیش‌نویس ممکن نشد.';
  @override
  String get couldNotUpdateStatus => 'به‌روزرسانی وضعیت ممکن نشد.';
  @override
  String get newApplicationDraft => 'پیش‌نویس درخواست جدید';
  @override
  String get toBeSelected => 'انتخاب‌نشده';
  @override
  String get pageNotFound => 'صفحه یافت نشد';
  @override
  String get nationality => 'ملیت';
  @override
  String get firstName => 'نام';
  @override
  String get lastName => 'نام خانوادگی';
  @override
  String get aboutYou => 'درباره شما';
  @override
  String get nationalityOptional => 'ملیت (اختیاری)';
  @override
  String get changesSaved => 'تغییرات ذخیره شد.';
  @override
  String get accountAlreadyExists => 'حسابی با این ایمیل وجود دارد.';
  @override
  String get otpInvalidOrExpired => 'کد تأیید نامعتبر یا منقضی است.';
  @override
  String get otpResent => 'کد جدید ارسال شد.';
  @override
  String get more => 'بیشتر';
  @override
  String get sendMessage => 'ارسال پیام';
  @override
  String get suggestionStudyPermitDocuments => 'مدارک معمول مجوز تحصیل چیست؟';
  @override
  String get suggestionVisaProcessingTime => 'فرایند ویزا چقدر طول می‌کشد؟';
  @override
  String get suggestionGteStatement => 'بیانیه GTE چیست؟';
  @override
  String aiUnavailableResponse(String question) =>
      'پایگاه دانش راد پیکربندی نشده است.\n\nسؤال شما: "$question"';
  @override
  String get newDocument => 'مدرک جدید';
  @override
  String get documentTypePassport => 'گذرنامه';
  @override
  String get documentTypeIdentity => 'مدرک هویت';
  @override
  String get documentTypeEducation => 'مدرک تحصیلی';
  @override
  String get documentTypeFinancial => 'مدرک مالی';
  @override
  String get documentTypeVisa => 'مدرک ویزا';
  @override
  String get documentTypeOther => 'سایر';
  @override
  String get documentStatusMissing => 'ناقص';
  @override
  String get documentStatusUploaded => 'بارگذاری‌شده';
  @override
  String get documentStatusUnderReview => 'در حال بررسی';
  @override
  String get documentStatusVerified => 'تأییدشده';
  @override
  String get documentStatusRejected => 'ردشده';
  @override
  String get adminAiConfig => 'پیکربندی هوش مصنوعی';
  @override
  String get providerModelConnection => 'ارائه‌دهندگان، مدل‌ها و اتصال';
  @override
  String get credentialsServerOnly =>
      'اعتبارنامه‌ها فقط سمت سرور نگهداری می‌شوند.';
  @override
  String get configurationUnavailable => 'پیکربندی در دسترس نیست.';
  @override
  String get noProviderConfigured => 'هنوز ارائه‌دهنده‌ای پیکربندی نشده است.';
  @override
  String get addOrUpdateProvider => 'افزودن یا به‌روزرسانی ارائه‌دهنده';
  @override
  String get slugLabel => 'شناسه';
  @override
  String get displayName => 'نام نمایشی';
  @override
  String get adapterType => 'آداپتر';
  @override
  String get publicHttpsOnly => 'باید آدرس HTTPS عمومی معتبر باشد';
  @override
  String get apiKeyWriteOnly => 'کلید API (فقط نوشتن)';
  @override
  String get keyMinimumEight => 'کلید باید حداقل ۸ کاراکتر باشد';
  @override
  String get keepCurrentCredential => 'برای حفظ اعتبار فعلی خالی بگذارید.';
  @override
  String get enabled => 'فعال';
  @override
  String get priority => 'اولویت';
  @override
  String get saveProvider => 'ذخیره ارائه‌دهنده';
  @override
  String get credentialConfigured => 'اعتبار پیکربندی شده';
  @override
  String get credentialMissing => 'اعتبار موجود نیست';
  @override
  String get testProvider => 'آزمایش ارائه‌دهنده';
  @override
  String get discoverModels => 'کشف مدل‌ها';
  @override
  String get runtimeScope => 'دامنه اجرا';
  @override
  String get trustClass => 'کلاس اعتماد';
  @override
  String get researchSource => 'منبع پژوهش';
  @override
  String get queueResearchRun => 'صف‌بندی اجرای پژوهش';
}
