import 'app_localizations.dart';

mixin AppLocalizationsFaB2 on AppLocalizations {
  @override
  String get adminResearchAssistant => 'دستیار پژوهش مدیریت';
  @override
  String get adminResearchSubtitle => 'پژوهش گسترده‌تر بدون انتشار خودکار.';
  @override
  String get untrustedResearchDisclaimer =>
      'محتوای بازیابی‌شده غیرقابل اعتماد است؛ انتشار خودکار انجام نمی‌شود.';
  @override
  String get providerSaved => 'ارائه‌دهنده ذخیره شد.';
  @override
  String get providerSaveFailed => 'ذخیره پیکربندی ممکن نشد.';
  @override
  String get providerTestFailed => 'آزمایش ارائه‌دهنده ناموفق بود.';
  @override
  String get modelDiscoveryFailed => 'کشف مدل ناموفق بود.';
  @override
  String get disabled => 'غیرفعال';
  @override
  String get active => 'فعال';
  @override
  String get inactive => 'غیرفعال';
  @override
  String get critical => 'بحرانی';
  @override
  String get unavailable => 'در دسترس نیست';
  @override
  String get baseUrl => 'آدرس پایه';
  @override
  String get lowercaseSlugHint => 'فقط حروف کوچک، رقم و زیرخط';
  @override
  String providerReachable(int count) =>
      'ارائه‌دهنده در دسترس است ($count مدل).';
  @override
  String modelDiscoveryCompleted(int discovered, int added) =>
      'کشف مدل: $discovered یافت شد، $added اضافه شد.';
  @override
  String get noContentSources => 'منبع محتوایی پیکربندی نشده است.';
  @override
  String get approvedSourcesAppearHere => 'منابع تأییدشده اینجا ظاهر می‌شوند.';
  @override
  String get noResearchJobs => 'هنوز کار پژوهشی نیست.';
  @override
  String get operationsHealth => 'سلامت عملیات';
  @override
  String get noOperationalComponents => 'مؤلفه عملیاتی ثبت نشده است.';
  @override
  String get componentInventoryUnavailable => 'فهرست مؤلفه‌ها در دسترس نیست.';
  @override
  String get auditSecurity => 'ممیزی / امنیت';
  @override
  String get noAuditEvents => 'رویداد ممیزی قابل مشاهده نیست.';
  @override
  String get auditRestricted => 'تاریخچه ممیزی محدود به مدیر ارشد است.';
  @override
  String get categoryUpdate => 'به‌روزرسانی';
  @override
  String get categoryGuide => 'راهنما';
  @override
  String get categoryDeadline => 'مهلت';
  @override
  String get categoryEvent => 'رویداد';
  @override
  String get categoryAnnouncement => 'اطلاعیه';
  @override
  String get sourceAddress => 'آدرس منبع';
  @override
  String get sourceSavedDisabled => 'منبع ذخیره شد. پس از بررسی فعال کنید.';
  @override
  String get sourceDuplicate => 'این آدرس قبلاً ثبت شده است.';
  @override
  String get sourceSaveFailed => 'ذخیره منبع ممکن نشد.';
  @override
  String get sourceEnable => 'فعال‌سازی منبع';
  @override
  String get sourceDisable => 'غیرفعال‌سازی منبع';
  @override
  String get researchSourcesTitle => 'منابع پژوهش';
  @override
  String get researchRunning => 'پژوهش در حال اجرا است.';
  @override
  String get researchRunFailed => 'پژوهش کامل نشد.';
  @override
  String get openReviewQueue => 'باز کردن صف بررسی';
  @override
  String get brandIntroTitle => 'گام بعدی شما با راد';
  @override
  String get brandIntroBody => 'مسیرهای ویزا، مدارک و پرونده در یک جا.';
  @override
  String get exploreVisa => 'کاوش مسیرهای ویزا';
  @override
  String get reviewQueueEmpty => 'یافته یا پیش‌نویسی در صف نیست.';
  @override
  String get sourceStateUnknown => 'هنوز اجرا نشده';
  @override
  String get sourceLastSuccess => 'آخرین دریافت موفق';
  @override
  String get sourceHttpRejected => 'از آدرس HTTPS عمومی استفاده کنید.';
  @override
  String get providerSavedDiscoveryFailed =>
      'ارائه‌دهنده ذخیره شد؛ کشف مدل ناموفق بود.';
  @override
  String get aiCredentialRejected =>
      'اعتبار ارائه‌دهنده نیاز به به‌روزرسانی دارد.';
  @override
  String get aiNoEligibleModel => 'مدل واجد شرایطی در دسترس نیست.';
  @override
  String get aiRateLimited => 'سرویس شلوغ است. کمی بعد تلاش کنید.';
  @override
  String get aiRequestFailed => 'درخواست هوش مصنوعی کامل نشد.';
  @override
  String get aiResponseNotSaved => 'این پاسخ ذخیره نشد.';
  @override
  String get addSource => 'افزودن منبع';
  @override
  String get requiredField => 'این فیلد الزامی است';
  @override
  String get invalidUrl => 'آدرس HTTPS عمومی معتبر وارد کنید';
  @override
  String get titleLabel => 'عنوان';
  @override
  String get sourceType => 'نوع منبع';
  @override
  String get researchPipelineSummary => 'خط لوله پژوهش';
  @override
  String findingsCount(int count) => '$count یافته در انتظار بررسی';
  @override
  String draftsInReview(int count) => '$count پیش‌نویس در بررسی';
  @override
  String get feedPublishedOnly => 'فید فقط موارد منتشرشده را نشان می‌دهد';
  @override
  String get lastResearchRun => 'آخرین اجرا';
  @override
  String get researchNeverAutoPublishes =>
      'پژوهش و هوش مصنوعی هرگز به‌صورت خودکار در فید منتشر نمی‌شوند.';
  @override
  String get researchQueued => 'اجرای پژوهش در صف قرار گرفت';
  @override
  String get reviewQueueTitle => 'صف بررسی انسانی';
  @override
  String get reviewDraftTitle => 'بررسی پیش‌نویس';
  @override
  String get reviewFindingTitle => 'بررسی یافته';
  @override
  String get reject => 'رد';
  @override
  String get keepPending => 'در انتظار بماند';
  @override
  String get approve => 'تأیید';
  @override
  String get publishExplicit => 'انتشار';
  @override
  String get publishRequiresHuman => 'انتشار نیاز به تأیید صریح انسانی دارد.';
  @override
  String get findingPublishNote => 'یافته‌ها به‌صورت خودکار منتشر نمی‌شوند.';
  @override
  String get editTitle => 'ویرایش عنوان';
  @override
  String get editBody => 'ویرایش متن';
  @override
  String get category => 'دسته';
  @override
  String get applicationSteps => 'مراحل درخواست';
  @override
  String get structuredSourceNote => 'یادداشت منبع ساختاری';
  @override
  String get publishedStatus => 'منتشرشده';
  @override
  String get draftStatusLabel => 'پیش‌نویس';
  @override
  String get reviewStatusLabel => 'در بررسی';
  @override
  String get scopeUser => 'کاربر';
  @override
  String get scopeBoth => 'کاربر و مدیر';
  @override
  String get healthOffline => 'آفلاین';
  @override
  String get healthHealthy => 'سالم';
  @override
  String get healthDegraded => 'کاهش‌یافته';
  @override
  String get healthUnknown => 'بررسی‌نشده';
  @override
  String get modelSaveFailed => 'ذخیره تنظیمات مدل ممکن نشد.';
  @override
  String get sourceQueryRejected =>
      'آدرس بدون query و با HTTPS عمومی استفاده کنید.';
}
