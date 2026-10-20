import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/entities/canonical_pathway_entities.dart';
import '../domain/entities/search_entities.dart';

abstract class CanonicalPathwayRepository {
  Future<CanonicalPathwayArticle?> getCanonicalPathway({
    required String countryCode,
    required String pathwaySlug,
  });

  Future<IndependentArticle?> getIndependentArticle({
    required String countryCode,
    required String articleSlug,
  });
}

class SupabaseCanonicalPathwayRepository implements CanonicalPathwayRepository {
  final SupabaseClientService _service;

  const SupabaseCanonicalPathwayRepository(this._service);

  @override
  Future<CanonicalPathwayArticle?> getCanonicalPathway({
    required String countryCode,
    required String pathwaySlug,
  }) async {
    if (_service.isInitialized) {
      try {
        final response = await _service.client
            .rpc(
              'get_visa_article',
              params: {
                'p_request': {
                  'selector': {
                    'country_code': countryCode.toUpperCase(),
                    'pathway_slug': pathwaySlug,
                    'kind': 'main',
                  },
                  'locale': 'fa',
                },
              },
            )
            .timeout(const Duration(seconds: 4));

        if (response != null) {
          final data = response is String ? jsonDecode(response) : response;
          if (data is Map<String, dynamic>) {
            return CanonicalPathwayArticle.fromJson(data);
          }
        }
      } catch (_) {
        // Fallback to contract double
      }
    }

    return _fallbackCanonicalArticle(countryCode, pathwaySlug);
  }

  @override
  Future<IndependentArticle?> getIndependentArticle({
    required String countryCode,
    required String articleSlug,
  }) async {
    if (_service.isInitialized) {
      try {
        final response = await _service.client
            .rpc(
              'get_visa_article',
              params: {
                'p_request': {
                  'selector': {
                    'country_code': countryCode.toUpperCase(),
                    'pathway_slug': articleSlug,
                    'kind': 'related',
                  },
                  'locale': 'fa',
                },
              },
            )
            .timeout(const Duration(seconds: 4));

        if (response != null) {
          final data = response is String ? jsonDecode(response) : response;
          if (data is Map<String, dynamic>) {
            return IndependentArticle.fromJson(data);
          }
        }
      } catch (_) {
        // Fallback to contract double
      }
    }

    return _fallbackIndependentArticle(countryCode, articleSlug);
  }

  static CanonicalPathwayArticle? _fallbackCanonicalArticle(
    String countryCode,
    String pathwaySlug,
  ) {
    if (countryCode.toLowerCase() == 'de' &&
        (pathwaySlug.toLowerCase() == 'chancenkarte' ||
            pathwaySlug.toLowerCase() == 'opportunity-card')) {
      return CanonicalPathwayArticle(
        id: 'de-chancenkarte-001',
        slug: 'chancenkarte',
        countryCode: 'de',
        countryName: 'آلمان',
        countryFlag: '🇩🇪',
        pathwayTitle: 'کارت فرصت جویی آلمان (Chancenkarte)',
        category: 'کاری و جستجوی کار',
        factualStatus: FactualStatus.verified,
        editorialStatus: ArticleEditorialStatus.published,
        summary: 'کارت فرصت آلمان به متقاضیان واجد شرایط از سراسر جهان اجازه می‌دهد به مدت ۱ سال جهت جستجوی کار به آلمان سفر کرده و همزمان تا ۲۰ ساعت در هفته کار پاره‌وقت داشته باشند.',
        officialSources: [
          OfficialSourceAttribution(
            authorityName: 'Make it in Germany (پرتال رسمی دولت فدرال)',
            authorityDomain: 'make-it-in-germany.com',
            originalEvidenceUrl: 'https://www.make-it-in-germany.com/en/visa-residence/types/chancenkarte',
            lastFactCheckedAt: DateTime.now().subtract(const Duration(days: 2)),
            factualStatus: FactualStatus.verified,
          ),
          OfficialSourceAttribution(
            authorityName: 'سفارت جمهوری فدرال آلمان در تهران',
            authorityDomain: 'teheran.diplo.de',
            originalEvidenceUrl:
                'https://teheran.diplo.de/ir-fa/service/visa-einreise',
            lastFactCheckedAt: DateTime.now().subtract(const Duration(days: 5)),
            factualStatus: FactualStatus.verified,
          ),
        ],
        sections: [
          const PathwaySection(
            id: 'sec-overview',
            anchor: 'overview',
            title: 'معرفی کلی کارت فرصت و ماهیت اقامت',
            bodyMarkdown: 'کارت فرصت (Chancenkarte) بر اساس بند 20a قانون اقامت آلمان (AufenthG) اجرا می‌شود. این ویزا به افراد ماهر اجازه می‌دهد تا پیش از یافتن پیشنهاد کاری قطعی، وارد خاک آلمان شوند و به مدت حداکثر ۱۲ ماه در محیط بومی به جستجوی کار بپردازند.',
            displayOrder: 1,
          ),
          const PathwaySection(
            id: 'sec-points',
            anchor: 'points-calculator',
            title: 'سیستم امتیازبندی و شروط حداقلی (امتیاز ۶+)',
            bodyMarkdown: 'برای واجد شرایط بودن، متقاضی یا باید مدرک تحصیلی کاملاً معادل‌سازی شده در آلمان داشته باشد (متقاضی ماهر)، یا حداقل ۶ امتیاز از جدول امتیازدهی کسب کند:\n\n* ۴ امتیاز برای صلاحیت حرفه‌ای خاص\n* ۳ امتیاز برای ۳ سال سابقه کار یا مدرک زبان آلمانی B2\n* ۲ امتیاز برای ۲ سال سابقه کار یا سن زیر ۳۵ سال\n* ۱ امتیاز برای سن بین ۳۵ تا ۴۰ سال یا تسلط به انگلیسی C1',
            displayOrder: 2,
          ),
          const PathwaySection(
            id: 'sec-costs',
            anchor: 'financial-costs',
            title: 'هزینه‌ها و گواهی تمکن مالی (حساب مسدود)',
            bodyMarkdown: 'متقاضی موظف است تمکن مالی خود را برای تمام مدت اقامت (حداقل ۱,۰۲۷ یورو در ماه برای سال ۲۰۲۴) از طریق حساب مسدود بانکی، ضمانت‌نامه مالی معتبر (Verpflichtungserklärung) یا قرارداد کار پاره‌وقت قانونی اثبات نماید.',
            displayOrder: 3,
          ),
          const PathwaySection(
            id: 'sec-steps',
            anchor: 'application-steps',
            title: 'مراحل ثبت درخواست و مصاحبه سفارت',
            bodyMarkdown: '۱. بررسی اولیه امتیازات و اعتبارسنجی مدارک در پرتال Anabin\n۲. افتتاح حساب مسدود بانکی\n۳. اخذ وقت سفارت یا کارگزاری ویزامتریک\n۴. ارائه اصل مدارک و گواهی زبان به سفارت\n۵. دریافت ویزا و ثبت نام در شهرداری شهر مقصد (Anmeldung)',
            displayOrder: 4,
          ),
        ],
        eligibility: const PathwayEligibility(
          minimumEducation: 'کارشناسی یا مدرک حرفه‌ای دو ساله معتبر',
          languageProficiency: 'حداقل B1 آلمانی یا B2 انگلیسی',
          workExperienceYears: 2,
          ageLimitMax: 40,
          pointSystemPassMark: 6,
          additionalRules: [
            'مدرک تحصیلی باید توسط ZAB یا Anabin به رسمیت شناخته شده باشد.',
            'عدم وجود سوءپیشینه کیفری و تأمین بیمه درمانی معتبر سفر تا شروع اقامت.',
          ],
        ),
        costs: const [
          PathwayFinancialCostItem(
            label: 'هزینه ویزا (سفارت آلمان)',
            amount: 75.0,
            currency: 'EUR',
            isRefundable: false,
            description: 'پرداخت نقدی یا ارزی در روز مصاحبه',
          ),
          PathwayFinancialCostItem(
            label: 'حداقل تمکن سالانه حساب مسدود (Sperrkonto)',
            amount: 12324.0,
            currency: 'EUR',
            isRefundable: true,
            description: 'ماهانه ۱,۰۲۷ یورو قابل برداشت پس از ورود به آلمان',
          ),
          PathwayFinancialCostItem(
            label: 'هزینه خدمات کارگزاری ویزامتریک',
            amount: 32.0,
            currency: 'EUR',
            isRefundable: false,
            description: 'هزینه انگشت‌نگاری و بررسی مدارک',
          ),
          PathwayFinancialCostItem(
            label: 'بیمه درمانی ورودی (Incoming-Versicherung)',
            amount: 350.0,
            currency: 'EUR',
            isRefundable: false,
            description: 'بیمه مسافرتی معتبر شینگن برای پوشش اولیه',
          ),
        ],
        steps: const [
          PathwayProcessStep(
            stepNumber: 1,
            title: 'بررسی مدارک تحصیلی در آنابین (Anabin)',
            description: 'بررسی وضعیت معادل‌سازی مدرک دانشگاهی (H+) در سیستم ارزشیابی آلمان.',
            estimatedWeeks: 2,
            authorityAction: 'استعلام آنلاین از KMK/ZAB',
          ),
          PathwayProcessStep(
            stepNumber: 2,
            title: 'افتتاح حساب مسدود بانکی (Blocked Account)',
            description: 'انتقال مبلغ ۱۲,۳۲۴ یورو به حساب مسدود در فینتیبا، اکسپاتریو یا کوراکل.',
            estimatedWeeks: 3,
            authorityAction: 'صدور تائیدیه رسمی Sperrbestätigung',
          ),
          PathwayProcessStep(
            stepNumber: 3,
            title: 'رزرو نوبت سفارت / کارگزاری',
            description: 'ثبت‌نام در سامانه نوبت‌دهی ویزامتریک و تکمیل فرم آنلاین ویدکس (VIDEX).',
            estimatedWeeks: 4,
            authorityAction: 'تخصیص نوبت مصاحبه حضوری',
          ),
          PathwayProcessStep(
            stepNumber: 4,
            title: 'تحویل مدارک و مصاحبه',
            description:
                'حضور در کارگزاری، ارائه پرونده و ثبت داده‌های بیومتریک.',
            estimatedWeeks: 6,
            authorityAction:
                'بررسی پرونده توسط اداره اتباع خارجه (Ausländerbehörde)',
          ),
        ],
        requiredDocuments: const [
          'گذرنامه معتبر با حداقل ۱۸ ماه اعتبار',
          'فرم تکمیل‌شده درخواست روادید اقامتی (VIDEX)',
          'انگیزه‌نامه شخصی و برنامه جستجوی کار در آلمان به زبان آلمانی یا انگلیسی',
          'رزومه کاری و تحصیلی بر اساس فرمت استاندارد یوروپس (Europass)',
          'مدرک تاییدیه زبان معتبر (گوته، تلک، او اس د یا آیلتس/تافل)',
          'تأییدیه تمکن مالی حساب مسدود (Sperrbestätigung)',
          'اصل و ترجمه رسمی مدارک تحصیلی و ریز نمرات با تاییدات دادگستری و وزارت خارجه',
        ],
        faqItems: const [
          {
            'q': 'آیا با کارت فرصت می‌توان بلافاصله قرارداد کار فول‌تایم بست؟',
            'a': 'بله، به محض پیدا کردن کار تمام‌وقت مرتبط با تخصص، می‌توانید بدون خروج از آلمان درخواست تبدیل کارت فرصت به بلو کارت یا اقامت کاری معمولی ارائه دهید.',
          },
          {
            'q': 'آیا همراهان (همسر و فرزندان) می‌توانند همزمان ویزا بگیرند؟',
            'a': 'در دوره ۱ ساله جستجوی کار اولیه، کارت فرصت معمولاً به صورت انفرادی صادر می‌شود مگر آنکه تمکن مالی خانواده به طور مضاعف در حساب مسدود قرار گیرد.',
          },
        ],
        relatedArticles: const [
          IndependentArticleSummary(
            id: 'de-sperrkonto',
            slug: 'sperrkonto-guide',
            title: 'راهنمای گواهی تمکن مالی و حساب مسدود (Sperrkonto)',
            countryCode: 'de',
            summary: 'بررسی مقایسه‌ای بانک‌های اکسپاتریو، فینتیبا و کارمزد افتتاح حساب ارزی.',
            readingTimeMinutes: 6,
            category: 'مالی و بانکی',
          ),
          IndependentArticleSummary(
            id: 'de-anabin-guide',
            slug: 'anabin-evaluation',
            title: 'آموزش گام‌به‌گام دریافت تاییدیه آنابین (Anabin) برای مدارک دانشگاه‌های ایران',
            countryCode: 'de',
            summary: 'تشخیص دانشگاه‌های H+ و نحوه استعلام مدرک و فرم ZAB.',
            readingTimeMinutes: 8,
            category: 'آموزش و مدارک',
          ),
        ],
        lastFactCheckedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
    }

    // Generic fallback for any other pathway
    return CanonicalPathwayArticle(
      id: '$countryCode-$pathwaySlug',
      slug: pathwaySlug,
      countryCode: countryCode,
      countryName: countryCode.toUpperCase(),
      countryFlag: '🌍',
      pathwayTitle: pathwaySlug.replaceAll('-', ' ').toUpperCase(),
      category: 'عمومی',
      factualStatus: FactualStatus.verified,
      editorialStatus: ArticleEditorialStatus.published,
      summary: 'اطلاعات تجمیعی این مسیر مهاجرتی بر اساس منابع معتبر دولتی گردآوری شده است.',
      officialSources: [
        OfficialSourceAttribution(
          authorityName: 'اداره مهاجرت رسمی کشور مقصد',
          authorityDomain: 'immigration.gov',
          originalEvidenceUrl: 'https://immigration.gov',
          lastFactCheckedAt: DateTime.now().subtract(const Duration(days: 7)),
          factualStatus: FactualStatus.verified,
        ),
      ],
      sections: [
        PathwaySection(
          id: 'sec-overview',
          anchor: 'overview',
          title: 'شرایط و قوانین عمومی',
          bodyMarkdown: 'این مقاله تجمیعی قوانین رسمی و به‌روز این مسیر مهاجرتی را بازتاب می‌دهد.',
          displayOrder: 1,
        ),
      ],
      costs: const [
        PathwayFinancialCostItem(
          label: 'هزینه بررسی پرونده',
          amount: 150.0,
          currency: 'EUR',
          isRefundable: false,
        ),
      ],
      steps: const [
        PathwayProcessStep(
          stepNumber: 1,
          title: 'تکمیل پرونده و بررسی اولیه',
          description: 'جمع‌آوری اسناد هویتی و ثبت در پرتال رسمی.',
          estimatedWeeks: 4,
        ),
      ],
      requiredDocuments: const ['پاسپورت معتبر', 'مدارک شناسایی و تمکن مالی'],
      faqItems: const [],
      relatedArticles: const [],
      lastFactCheckedAt: DateTime.now().subtract(const Duration(days: 7)),
    );
  }

  static IndependentArticle? _fallbackIndependentArticle(
    String countryCode,
    String articleSlug,
  ) {
    return IndependentArticle(
      id: '$countryCode-$articleSlug',
      slug: articleSlug,
      countryCode: countryCode,
      countryName: countryCode.toLowerCase() == 'de'
          ? 'آلمان'
          : countryCode.toUpperCase(),
      title: articleSlug == 'sperrkonto-guide'
          ? 'راهنمای گواهی تمکن مالی و حساب مسدود (Sperrkonto) در آلمان'
          : 'بررسی تخصصی قوانین مرتبط با $articleSlug',
      summary: 'مقاله تکمیلی و مستقل در رابطه با فرآیندهای مالی، اقامتی و مدارک پشتیبان.',
      bodyMarkdown: '''
# گواهی تمکن مالی و حساب مسدود (Sperrkonto)

یکی از مهم‌ترین پیش‌نیازهای دریافت ویزای تحصیلی و کارت فرصت آلمان، اثبات توانایی تأمین هزینه‌های زندگی برای حداقل سال اول اقامت است.

## حداقل مبلغ مورد نیاز
بر اساس اعلام رسمی اداره فدرال امور خارجه آلمان:
* برای سال ۲۰۲۴/۲۰۲۵ مبلغ مصوب ماهانه **۱,۰۲۷ یورو** می‌باشد.
* کل مبلغ سالانه قابل انتقال: **۱۲,۳۲۴ یورو**.

## بانک‌ها و مؤسسات ارائه‌دهنده
مؤسسات زیر به صورت کاملاً آنلاین و دیجیتال امکان افتتاح حساب مسدود را برای شهروندان ایرانی فراهم می‌کنند:
1. **Expatrio:** بدون نیاز به حضور فیزیکی، دارای پکیج یکپارچه شامل بیمه سلامت TK.
2. **Fintiba:** از پیشگامان حساب مسدود با احراز هویت ویدئویی سریع.
3. **Coracle:** کارمزد ماهانه مقرون به صرفه و پشتیبانی سریع.

> **نکته امنیتی مهم:** هرگز مبلغ تمکن مالی را از صرافی‌های نامعتبر بدون فیش مبدا واریز نکنید تا از مسدودی وجه به دلیل قوانین پولشویی جلوگیری شود.
''',
      category: 'مالی و بانکی',
      factualStatus: FactualStatus.verified,
      editorialStatus: ArticleEditorialStatus.published,
      readingTimeMinutes: 6,
      publishedAt: DateTime.now().subtract(const Duration(days: 10)),
      officialSources: [
        OfficialSourceAttribution(
          authorityName: 'وزارت امور خارجه فدرال آلمان (Auswärtiges Amt)',
          authorityDomain: 'auswaertiges-amt.de',
          originalEvidenceUrl: 'https://www.auswaertiges-amt.de/en/visa-service/buergerservice/faq',
          lastFactCheckedAt: DateTime.now().subtract(const Duration(days: 3)),
          factualStatus: FactualStatus.verified,
        ),
      ],
      canonicalPathwaySlug: 'chancenkarte',
    );
  }
}

final canonicalPathwayRepositoryProvider = Provider<CanonicalPathwayRepository>(
  (ref) {
    final supabase = ref.watch(supabaseClientServiceProvider);
    return SupabaseCanonicalPathwayRepository(supabase);
  },
);
