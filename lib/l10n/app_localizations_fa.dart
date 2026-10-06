import 'app_localizations.dart';

class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([super.localeName = 'fa']);

  @override
  String get appTitle => 'موسسه بین‌المللی راد';
  @override
  String get signIn => 'ورود';
  @override
  String get signInSubtitle => 'برای مدیریت پرونده مهاجرتی خود وارد شوید';
  @override
  String get email => 'ایمیل';
  @override
  String get password => 'رمز عبور';
  @override
  String get showPassword => 'نمایش رمز عبور';
  @override
  String get hidePassword => 'مخفی کردن رمز عبور';
  @override
  String get required => 'الزامی';
  @override
  String get createAccount => 'ایجاد حساب کاربری';
  @override
  String get continueWithOtp => 'ادامه با کد یک‌بارمصرف';
  @override
  String get forgotPassword => 'رمز عبور را فراموش کرده‌اید؟';
  @override
  String get signUp => 'ثبت‌نام';
  @override
  String get alreadyHaveAccount => 'قبلاً حساب دارید؟ وارد شوید';
  @override
  String get fullName => 'نام کامل';
  @override
  String get phone => 'تلفن';
  @override
  String get confirmPassword => 'تأیید رمز عبور';
  @override
  String get passwordsDoNotMatch => 'رمزهای عبور یکسان نیستند';
  @override
  String get passwordTooShort => 'رمز عبور باید حداقل ۸ کاراکتر باشد';
  @override
  String get invalidEmail => 'یک آدرس ایمیل معتبر وارد کنید';
  @override
  String get otpTitle => 'کد تأیید را وارد کنید';
  @override
  String get otpSubtitle => 'یک کد ۶ رقمی به ایمیل شما ارسال شد';
  @override
  String get otpCode => 'کد تأیید';
  @override
  String get verify => 'تأیید';
  @override
  String get resendCode => 'ارسال مجدد کد';
  @override
  String resendIn(int seconds) => 'ارسال مجدد تا $seconds ثانیه';
  @override
  String get profileCompletionTitle => 'تکمیل پروفایل';
  @override
  String get profileCompletionSubtitle =>
      'چند جزئیات به شخصی‌سازی تجربه شما کمک می‌کند';
  @override
  String get saveAndContinue => 'ذخیره و ادامه';
  @override
  String get home => 'خانه';
  @override
  String get visa => 'ویزا';
  @override
  String get cases => 'پرونده‌ها';
  @override
  String get docs => 'مدارک';
  @override
  String get profile => 'پروفایل';
  @override
  String get feed => 'اخبار';
  @override
  String get aiAssistant => 'دستیار هوشمند';
  @override
  String get admin => 'مدیریت';
  @override
  String get dashboard => 'داشبورد';
  @override
  String get logout => 'خروج';
  @override
  String get settings => 'تنظیمات';
  @override
  String get language => 'زبان';
  @override
  String get theme => 'پوسته';
  @override
  String get themeLight => 'روشن';
  @override
  String get themeDark => 'تیره';
  @override
  String get themeSystem => 'سیستم';
  @override
  String get english => 'انگلیسی';
  @override
  String get persian => 'فارسی';
  @override
  String get loading => 'در حال بارگذاری…';
  @override
  String get retry => 'تلاش مجدد';
  @override
  String get errorGeneric => 'مشکلی پیش آمد. لطفاً دوباره تلاش کنید.';
  @override
  String get errorNetwork =>
      'خطای شبکه. اتصال خود را بررسی کنید و دوباره تلاش کنید.';
  @override
  String get errorAuthInvalid => 'ایمیل یا رمز عبور نامعتبر است.';
  @override
  String get errorAuthSession =>
      'نشست شما منقضی شده است. لطفاً دوباره وارد شوید.';
  @override
  String get emptyState => 'هنوز چیزی اینجا نیست';
  @override
  String get cancel => 'انصراف';
  @override
  String get save => 'ذخیره';
  @override
  String get delete => 'حذف';
  @override
  String get confirm => 'تأیید';
  @override
  String get back => 'بازگشت';
  @override
  String get next => 'بعدی';
  @override
  String get search => 'جستجو';
  @override
  String get filter => 'فیلتر';
  @override
  String get status => 'وضعیت';
  @override
  String get documents => 'مدارک';
  @override
  String get applications => 'درخواست‌ها';
  @override
  String get noDocuments => 'هنوز مدرکی بارگذاری نشده است';
  @override
  String get noApplications => 'هنوز درخواستی ثبت نشده است';
  @override
  String get uploadDocument => 'بارگذاری مدرک';
  @override
  String get viewDetails => 'مشاهده جزئیات';
  @override
  String get resetPassword => 'بازنشانی رمز عبور';
  @override
  String get setNewPassword => 'تنظیم رمز عبور جدید';
  @override
  String get newPassword => 'رمز عبور جدید';
  @override
  String get passwordResetSent =>
      'اگر حسابی با این ایمیل وجود داشته باشد، لینک بازنشانی ارسال شد.';
  @override
  String get passwordUpdated =>
      'رمز عبور با موفقیت به‌روزرسانی شد. اکنون می‌توانید وارد شوید.';
  @override
  String get sendResetLink => 'ارسال لینک بازنشانی';
  @override
  String get backToSignIn => 'بازگشت به ورود';
  @override
  String get yourJourney => 'مسیر شما';
  @override
  String helloName(String name) => 'سلام، $name';
  @override
  String get travelerFallback => 'مسافر';
  @override
  String get needsYourAction => 'نیاز به اقدام شما';
  @override
  String get needsActionSubtitle =>
      'این موارد را تکمیل کنید تا پرونده شما پیش برود';
  @override
  String get completeProfileTitle => 'تکمیل پروفایل';
  @override
  String get completeProfileSubtitle => 'نام و جزئیات اولیه را وارد کنید';
  @override
  String documentsMissingCount(int count) => '$count مدرک ناقص';
  @override
  String get documentMissingOne => '۱ مدرک ناقص';
  @override
  String get reviewRequiredFiles => 'مدارک موردنیاز پرونده را بررسی کنید';
  @override
  String get actionBadge => 'اقدام';
  @override
  String get caseOverview => 'نمای کلی پرونده';
  @override
  String get caseOverviewSubtitle => 'نگاهی سریع به کارهای فعال شما';
  @override
  String get allCases => 'همه پرونده‌ها';
  @override
  String get activeCases => 'پرونده‌های فعال';
  @override
  String get documentsMissing => 'مدارک ناقص';
  @override
  String get quickActions => 'اقدامات سریع';
  @override
  String get quickActionsSubtitle =>
      'از جایی که امروز به کمک نیاز دارید شروع کنید';
  @override
  String get visaPrograms => 'برنامه‌های ویزا';
  @override
  String get radUpdates => 'تازه‌های راد';
  @override
  String get shortcuts => 'میانبرها';
  @override
  String get profileShortcutSubtitle => 'اطلاعات شخصی و مهاجرتی';
  @override
  String get askAssistant => 'پرسش از دستیار';
  @override
  String get askAssistantSubtitle => 'ویزا، مدارک و راهنمایی فرآیند';
  @override
  String get nextStepReady => 'گام بعدی شما آماده است';
  @override
  String get onTrack => 'مسیر شما در جریان است';
  @override
  String get nextStepDescription =>
      'چند مورد نیاز به توجه شما دارد تا پرونده پیش برود.';
  @override
  String get onTrackDescription =>
      'اطلاعات پرونده به‌روز است. پیشرفت را بررسی کنید یا راهنمایی بخواهید.';
  @override
  String get reviewNextStep => 'بررسی گام بعدی';
  @override
  String get viewApplications => 'مشاهده درخواست‌ها';
  @override
  String get refresh => 'بروزرسانی';
  @override
  String get progress => 'پیشرفت';
  @override
  String get updateStatus => 'به‌روزرسانی وضعیت';
  @override
  String get updateStatusHint =>
      'فقط برای ثبت آخرین وضعیت تأییدشده پرونده استفاده کنید.';
  @override
  String get newDraft => 'پیش‌نویس جدید';
  @override
  String get creating => 'در حال ایجاد…';
  @override
  String get loadingApplications => 'در حال بارگذاری درخواست‌ها…';
  @override
  String get noApplicationsSubtitle =>
      'یک پیش‌نویس بسازید یا برنامه‌های ویزا را بررسی کنید.';
  @override
  String get statusDraft => 'پیش‌نویس';
  @override
  String get statusSubmitted => 'ارسال‌شده';
  @override
  String get statusReviewing => 'در حال بررسی';
  @override
  String get statusDocumentsRequired => 'نیاز به مدرک';
  @override
  String get statusApproved => 'تأییدشده';
  @override
  String get statusRejected => 'ردشده';
  @override
  String get statusCompleted => 'تکمیل‌شده';
  @override
  String get loadingDocuments => 'در حال بارگذاری مدارک…';
  @override
  String get addType => 'افزودن نوع';
  @override
  String get missingSection => 'ناقص';
  @override
  String get missingSectionSubtitle =>
      'این موارد را بارگذاری کنید تا درخواست ادامه یابد';
  @override
  String get allDocuments => 'همه مدارک';
  @override
  String get submittedSection => 'ارسال‌شده';
  @override
  String get noDocumentsSubtitle =>
      'انواع مدارک موردنیاز پرونده را اضافه کنید.';
  @override
  String get chooseFileUpload => 'انتخاب فایل و بارگذاری';
  @override
  String get deleteDocument => 'حذف مدرک';
  @override
  String get deleteDocumentTitle => 'حذف مدرک؟';
  @override
  String get deleteDocumentBody =>
      'این کار رکورد مدرک و فایل خصوصی آن را حذف می‌کند.';
  @override
  String get close => 'بستن';
  @override
  String get acceptedFormats =>
      'فرمت‌های مجاز: PDF، JPG، JPEG و PNG. حداکثر حجم: ۱۰ مگابایت.';
  @override
  String get couldNotReadFile => 'خواندن فایل ممکن نشد.';
  @override
  String get fileTooLarge => 'حجم فایل باید حداکثر ۱۰ مگابایت باشد.';
  @override
  String get uploadFailed => 'بارگذاری ناموفق بود. لطفاً دوباره تلاش کنید.';
  @override
  String get deleteFailed => 'حذف ناموفق بود. لطفاً دوباره تلاش کنید.';
  @override
  String get typeLabel => 'نوع';
  @override
  String get statusLabel => 'وضعیت';
  @override
  String get aiDisclaimer =>
      'پاسخ‌های منبع‌دار تا زمان پیکربندی پایگاه دانش راد در دسترس نیست. هیچ‌یک از این موارد تصمیم رسمی مهاجرتی نیست.';
  @override
  String get howCanWeHelp => 'چطور می‌توانیم کمک کنیم؟';
  @override
  String get askAboutVisas =>
      'درباره ویزا، مدارک یا فرآیند بپرسید. یک پیشنهاد را امتحان کنید:';
  @override
  String get askQuestionHint => 'سؤال خود را بنویسید…';
  @override
  String freeQuota(int used, int limit) => '$used / $limit رایگان';
  @override
  String get aiQuotaExhausted =>
      'سقف پرسش‌های رایگان این نشست استفاده شده است.';
  @override
  String get couldNotSaveQuestion =>
      'ذخیره سؤال ممکن نشد. لطفاً دوباره تلاش کنید.';
  @override
  String get sourceLabel => 'منبع';
  @override
  String get adminOperations => 'عملیات مدیریت';
  @override
  String get loadingOperational => 'در حال بارگذاری داده‌های عملیاتی…';
  @override
  String get adminLoadFailed => 'بارگذاری عملیات مدیریت ممکن نشد.';
  @override
  String get adminRestricted =>
      'این مسیر فقط برای مدیران تأییدشده راد در دسترس است.';
  @override
  String get superAdmin => 'مدیر ارشد';
  @override
  String get operationalOverview => 'نمای عملیاتی';
  @override
  String get researchJobs => 'وظایف پژوهش';
  @override
  String get aiRequests => 'درخواست‌های هوش مصنوعی';
  @override
  String get documentJobs => 'وظایف مدارک';
  @override
  String get openTasks => 'وظایف باز';
  @override
  String get auditEvents => 'رویدادهای ممیزی';
  @override
  String get serverEnforcedAccess => 'دسترسی اعمال‌شده در سرور';
  @override
  String get serverEnforcedAccessBody =>
      'یادداشت پرونده، وظایف، تاریخچه وضعیت، سلامت ارائه‌دهنده و تغییر نقش‌ها با RLS و رویدادهای ممیزی محافظت می‌شوند.';
  @override
  String get visaPathways => 'مسیرهای مهاجرت و ویزا';
  @override
  String get loadingCatalogue => 'در حال دریافت اطلاعات…';
  @override
  String get catalogueUnavailable =>
      'دریافت اطلاعات ممکن نشد. لطفاً دوباره تلاش کنید.';
  @override
  String get findPathway => 'مسیر مناسب را پیدا کنید';
  @override
  String get catalogueDisclaimer =>
      'فقط محتوای منتشرشده و منبع‌دار نمایش داده می‌شود. شرایط روز را همیشه با مرجع رسمی بررسی کنید.';
  @override
  String get searchProgrammes => 'جست‌وجوی کشور یا مسیر';
  @override
  String get allDestinations => 'همه کشورها';
  @override
  String get allServices => 'همه خدمات';
  @override
  String get noProgrammeFound => 'موردی پیدا نشد';
  @override
  String get tryChangingFilters => 'فیلترها یا عبارت جست‌وجو را تغییر دهید.';
  @override
  String get publishedTimeline => 'زمان اعلام‌شده';
  @override
  String get publishedFee => 'هزینه اعلام‌شده';
  @override
  String get publishedRequirements => 'مدارک و الزامات منتشرشده';
  @override
  String get structuredDetailsPending =>
      'جزئیات ساختاریافته در انتظار بازبینی است';
  @override
  String get structuredDetailsPendingBody =>
      'هنوز الزامات یا مراحل اقدامِ تأییدشده‌ای برای این برنامه منتشر نشده است. منبع ذکرشده را ببینید و مقررات روز را با مرجع رسمی تطبیق دهید.';
  @override
  String get source => 'منبع';
  @override
  String get visaDisclaimer =>
      'این اطلاعات تضمین نتیجه نیست و جایگزین بررسی مقررات رسمی یا مشاوره تخصصی نمی‌شود.';
  @override
  String get feedTitle => 'تازه‌های راد';
  @override
  String get loadingUpdates => 'در حال بارگذاری تازه‌ها…';
  @override
  String get updatesLoadFailed => 'دریافت تازه‌ها ممکن نشد.';
  @override
  String get noReviewedUpdates => 'هنوز محتوای تأییدشده‌ای منتشر نشده است.';
  @override
  String get bookmark => 'نشان‌گذاری';
  @override
  String get removeBookmark => 'حذف نشان';
  @override
  String get backToApplications => 'بازگشت به درخواست‌ها';
  @override
  String get couldNotCreateDraft =>
      'ایجاد پیش‌نویس ممکن نشد. لطفاً دوباره تلاش کنید.';
  @override
  String get couldNotUpdateStatus =>
      'به‌روزرسانی وضعیت ممکن نشد. لطفاً دوباره تلاش کنید.';
  @override
  String get newApplicationDraft => 'پیش‌نویس درخواست جدید';
  @override
  String get toBeSelected => 'انتخاب‌نشده';
  @override
  String get pageNotFound => 'صفحه پیدا نشد';
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
  String get accountAlreadyExists =>
      'با این ایمیل حسابی وجود دارد. لطفاً وارد شوید.';
  @override
  String get otpInvalidOrExpired =>
      'کد تأیید نامعتبر است یا اعتبار آن به پایان رسیده است.';
  @override
  String get otpResent => 'کد تأیید جدید ارسال شد.';
  @override
  String get more => 'بیشتر';
  @override
  String get sendMessage => 'ارسال پیام';
  @override
  String get suggestionStudyPermitDocuments =>
      'برای مجوز تحصیلی معمولاً چه مدارکی لازم است؟';
  @override
  String get suggestionVisaProcessingTime =>
      'فرایند بررسی ویزا ممکن است چقدر طول بکشد؟';
  @override
  String get suggestionGteStatement => 'نامه GTE چیست؟';
  @override
  String aiUnavailableResponse(String question) =>
      'پایگاه دانش RAD برای این نسخه پیکربندی نشده است.\n\n'
      'پرسش شما: «$question»\n\n'
      'پس از پیکربندی ارائه‌دهندهٔ تأییدشده، پاسخ‌های مستند در دسترس خواهند '
      'بود. در این پیام هیچ الزام مهاجرتی استنباط نشده است.';
  @override
  String get newDocument => 'مدرک جدید';
  @override
  String get documentTypePassport => 'گذرنامه';
  @override
  String get documentTypeIdentity => 'مدرک هویتی';
  @override
  String get documentTypeEducation => 'مدرک تحصیلی';
  @override
  String get documentTypeFinancial => 'مدرک مالی';
  @override
  String get documentTypeVisa => 'مدرک ویزا';
  @override
  String get documentTypeOther => 'سایر';
  @override
  String get documentStatusMissing => 'موجود نیست';
  @override
  String get documentStatusUploaded => 'بارگذاری‌شده';
  @override
  String get documentStatusUnderReview => 'در حال بررسی';
  @override
  String get documentStatusVerified => 'تأییدشده';
  @override
  String get documentStatusRejected => 'ردشده';
  @override
  String get adminAiConfig => 'تنظیمات هوش مصنوعی';
  @override
  String get providerModelConnection => 'ارائه‌دهندگان، مدل‌ها و اتصال API';
  @override
  String get credentialsServerOnly =>
      'کلیدهای دسترسی فقط در سرور نگهداری می‌شوند و مقدار ذخیره‌شده هرگز به مرورگر بازگردانده نمی‌شود.';
  @override
  String get configurationUnavailable => 'دریافت تنظیمات ممکن نشد.';
  @override
  String get noProviderConfigured =>
      'هنوز ارائه‌دهنده‌ای پیکربندی نشده است. از فرم زیر برای راه‌اندازی اولیه استفاده کنید.';
  @override
  String get addOrUpdateProvider => 'افزودن یا به‌روزرسانی ارائه‌دهنده';
  @override
  String get slugLabel => 'شناسه';
  @override
  String get displayName => 'نام نمایشی';
  @override
  String get adapterType => 'آداپتر';
  @override
  String get publicHttpsOnly => 'باید یک نشانی HTTPS عمومی معتبر باشد';
  @override
  String get apiKeyWriteOnly => 'کلید API (فقط نوشتنی)';
  @override
  String get keyMinimumEight => 'کلید باید حداقل ۸ کاراکتر باشد';
  @override
  String get keepCurrentCredential =>
      'برای حفظ کلید فعلی، این بخش را خالی بگذارید.';
  @override
  String get enabled => 'فعال';
  @override
  String get priority => 'اولویت';
  @override
  String get saveProvider => 'ذخیره ارائه‌دهنده';
  @override
  String get credentialConfigured => 'کلید ثبت شده';
  @override
  String get credentialMissing => 'کلید ثبت نشده';
  @override
  String get testProvider => 'آزمایش ارائه‌دهنده';
  @override
  String get discoverModels => 'کشف مدل‌ها';
  @override
  String get runtimeScope => 'دامنه اجرا';
  @override
  String get trustClass => 'رده اعتماد';
  @override
  String get researchSource => 'منبع پژوهش';
  @override
  String get queueResearchRun => 'افزودن پژوهش به صف';
  @override
  String get adminResearchAssistant => 'دستیار پژوهش مدیریت';
  @override
  String get adminResearchSubtitle =>
      'پژوهش گسترده‌تر با حفظ شواهد، منشأ و تعارض‌ها؛ بدون انتشار خودکار.';
  @override
  String get untrustedResearchDisclaimer =>
      'محتوای بازیابی‌شده غیرقابل‌اعتماد است؛ تعارض‌ها حفظ می‌شوند و هیچ مطلبی خودکار منتشر نمی‌شود.';
  @override
  String get providerSaved =>
      'ارائه‌دهنده ذخیره شد. کلید در سرور نگهداری می‌شود و دوباره نمایش داده نخواهد شد.';
  @override
  String get providerSaveFailed =>
      'ذخیره تنظیمات ممکن نشد. نقش مدیر ارشد و صحت ورودی‌ها را بررسی کنید.';
  @override
  String get providerTestFailed =>
      'آزمایش ارائه‌دهنده با یک خطای پالایش‌شده ناموفق بود.';
  @override
  String get modelDiscoveryFailed =>
      'کشف مدل‌ها با یک خطای پالایش‌شده ناموفق بود.';
  @override
  String get disabled => 'غیرفعال';
  @override
  String get active => 'فعال';
  @override
  String get inactive => 'غیرفعال';
  @override
  String get critical => 'حیاتی';
  @override
  String get unavailable => 'در دسترس نیست';
  @override
  String get baseUrl => 'نشانی پایه';
  @override
  String get lowercaseSlugHint =>
      'فقط از حروف کوچک انگلیسی، رقم و زیرخط استفاده کنید';
  @override
  String providerReachable(int count) =>
      'ارائه‌دهنده در دسترس است ($count مدل قابل مشاهده).';
  @override
  String modelDiscoveryCompleted(int discovered, int added) =>
      'کشف مدل‌ها انجام شد: $discovered مدل پیدا و $added مدل افزوده شد.';
  @override
  String get noContentSources => 'هنوز منبع محتوایی پیکربندی نشده است.';
  @override
  String get approvedSourcesAppearHere =>
      'منابع رسمی راد و منابع معتبر تأییدشده در این بخش نمایش داده می‌شوند.';
  @override
  String get noResearchJobs => 'هنوز پژوهشی در صف قرار نگرفته است.';
  @override
  String get operationsHealth => 'عملیات و سلامت سامانه';
  @override
  String get noOperationalComponents => 'هیچ مؤلفه عملیاتی ثبت نشده است.';
  @override
  String get componentInventoryUnavailable =>
      'فهرست مؤلفه‌های سامانه در دسترس نیست.';
  @override
  String get auditSecurity => 'ممیزی و امنیت';
  @override
  String get noAuditEvents => 'هیچ رویداد ممیزی قابل مشاهده نیست.';
  @override
  String get auditRestricted =>
      'تاریخچه ممیزی فقط برای مدیر ارشد در دسترس است.';
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
  String get reviewQueueTitle => 'صف بررسی';
  @override
  String get reviewDraftTitle => 'پیش‌نویس تحریریه';
  @override
  String get reviewFindingTitle => 'یافته پژوهشی';
  @override
  String get reject => 'رد';
  @override
  String get keepPending => 'نگه‌داشتن در انتظار';
  @override
  String get approve => 'تأیید';
  @override
  String get publishExplicit => 'انتشار در فید';
  @override
  String get publishRequiresHuman =>
      'انتشار یک اقدام عمدی مدیر است. پژوهش و هوش مصنوعی هرگز به‌صورت خودکار منتشر نمی‌کنند.';
  @override
  String get findingPublishNote =>
      'تأیید یافته به‌تنهایی مطلب را در فید عمومی منتشر نمی‌کند. برای انتشار، پیش‌نویس تحریریه بسازید یا ارتقا دهید.';
  @override
  String get editTitle => 'عنوان';
  @override
  String get editBody => 'متن';
  @override
  String get category => 'دسته';
  @override
  String get applicationSteps => 'مراحل اقدام';
  @override
  String get structuredSourceNote =>
      'اطلاعات بالا از محتوای ساختاریافته و منبع ثبت‌شده تهیه شده است؛ لینک خام به‌جای محتوا نمایش داده نمی‌شود.';
  @override
  String get publishedStatus => 'منتشرشده';
  @override
  String get draftStatusLabel => 'پیش‌نویس';
  @override
  String get reviewStatusLabel => 'در حال بررسی';
}
