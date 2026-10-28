import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/admin_cms_entities.dart';
import '../domain/entities/admin_research_models.dart';
import 'admin_cms_repository.dart';

/// Comprehensive mock repository and adapter for the Research Assistant prototype.
/// Provides rich, realistic Persian research data for all 5 screens.
class MockResearchAdminRepository implements AdminCmsRepository {
  // Screen 1: Dashboard Metrics
  ResearchDashboardMetrics getDashboardMetrics() {
    return ResearchDashboardMetrics(
      monitoredCountriesCount: 5,
      activeOfficialSourcesCount: 18,
      employerAddedSourcesCount: 4,
      monitoredUniversitiesCount: 12,
      detectedChangesCount: 7,
      pendingAdminReviewsCount: 4,
      monitoringFailuresCount: 2,
      overdueSourceChecksCount: 3,
      lastCrawlCompletedAt: DateTime.now().subtract(
        const Duration(minutes: 24),
      ),
    );
  }

  // Screen 2: Managed Sources
  final List<ManagedResearchSource> _sources = [
    ManagedResearchSource(
      id: 'src-ca-ircc',
      name: 'اداره مهاجرت، پناهندگی و شهروندی کانادا (IRCC)',
      baseUrl: 'https://www.canada.ca/en/immigration-refugees-citizenship.html',
      countryCode: 'CA',
      topic: 'مهاجرت کاری، تحصیلی و اقامت دائم',
      relevantArticles: [
        'اکسپرس اینتری (FSWP)',
        'برنامه نامزدی استانی (PNP)',
        'ویزای تحصیلی',
      ],
      verificationTier: SourceVerificationTier.officialAuthority,
      isEnabled: true,
      interval: MonitoringInterval.daily,
      lastCheckedAt: DateTime.now().subtract(const Duration(hours: 3)),
      nextScheduledCheckAt: DateTime.now().add(const Duration(hours: 21)),
      connectionStatus: 'ok_200',
    ),
    ManagedResearchSource(
      id: 'src-de-auswaertiges',
      name: 'وزارت امور خارجه جمهوری فدرال آلمان (Auswärtiges Amt)',
      baseUrl: 'https://www.auswaertiges-amt.de/de/service/visa-und-aufenthalt',
      countryCode: 'DE',
      topic: 'ویزای دانشجویی، کارت شانس (Chancenkarte) و بلوکارت',
      relevantArticles: [
        'کارت شانس آلمان',
        'ویزای تحصیلی آلمان',
        'بلوکارت کاری',
      ],
      verificationTier: SourceVerificationTier.officialAuthority,
      isEnabled: true,
      interval: MonitoringInterval.daily,
      lastCheckedAt: DateTime.now().subtract(const Duration(hours: 6)),
      nextScheduledCheckAt: DateTime.now().add(const Duration(hours: 18)),
      connectionStatus: 'ok_200',
    ),
    ManagedResearchSource(
      id: 'src-au-homeaffairs',
      name: 'وزارت امور داخلی استرالیا (Department of Home Affairs)',
      baseUrl:
          'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-listing',
      countryCode: 'AU',
      topic: 'ویزاهای اسکیل ورکر ساب‌کلاس ۱۸۹، ۱۹۰ و فارغ‌التحصیلی ۴۸۵',
      relevantArticles: [
        'ویزای ۱۸۹ استرالیا',
        'ویزای ۱۹۰ استرالیا',
        'ویزای ۴۸۵ فارغ‌التحصیلی',
      ],
      verificationTier: SourceVerificationTier.officialAuthority,
      isEnabled: true,
      interval: MonitoringInterval.every12Hours,
      lastCheckedAt: DateTime.now().subtract(const Duration(hours: 14)),
      nextScheduledCheckAt: DateTime.now().subtract(
        const Duration(hours: 2),
      ), // Overdue
      connectionStatus: 'ok_200',
    ),
    ManagedResearchSource(
      id: 'src-uk-ukvi',
      name: 'سازمان ویزا و مهاجرت بریتانیا (UKVI / Home Office)',
      baseUrl: 'https://www.gov.uk/browse/visas-immigration',
      countryCode: 'UK',
      topic: 'ویزای نیروی کار ماهر (Skilled Worker) و ویزای دانشجویی',
      relevantArticles: [
        'ویزای کاری اسکیلد ورکر انگلستان',
        'ویزای تحصیلی دانش‌آموزی و دانشجویی بریتانیا',
      ],
      verificationTier: SourceVerificationTier.officialAuthority,
      isEnabled: true,
      interval: MonitoringInterval.daily,
      lastCheckedAt: DateTime.now().subtract(const Duration(hours: 5)),
      nextScheduledCheckAt: DateTime.now().add(const Duration(hours: 19)),
      connectionStatus: 'ok_200',
    ),
    ManagedResearchSource(
      id: 'src-ca-uoft',
      name: 'پورتال رسمی پذیرش بین‌الملل دانشگاه تورنتو (U of T)',
      baseUrl: 'https://future.utoronto.ca/international-students/',
      countryCode: 'CA',
      universityName: 'دانشگاه تورنتو (University of Toronto)',
      topic: 'پذیرش تحصیلی، شرایط زبان و بورسیه Lester B. Pearson',
      relevantArticles: [
        'تحصیل در دانشگاه تورنتو',
        'بورسیه‌های برتر دانشگاه‌های کانادا',
      ],
      verificationTier: SourceVerificationTier.accreditedUniversity,
      isEnabled: true,
      interval: MonitoringInterval.weekly,
      lastCheckedAt: DateTime.now().subtract(const Duration(days: 2)),
      nextScheduledCheckAt: DateTime.now().add(const Duration(days: 5)),
      connectionStatus: 'ok_200',
    ),
    ManagedResearchSource(
      id: 'src-de-tum',
      name: 'پورتال بین‌المللی دانشگاه فنی مونیخ (TUM)',
      baseUrl: 'https://www.tum.de/en/studies/international-students',
      countryCode: 'DE',
      universityName: 'دانشگاه فنی مونیخ (Technical University of Munich)',
      topic: 'پذیرش کارشناسی ارشد مهندسی و شهریه دانشجویان خارجی',
      relevantArticles: ['تحصیل رایگان در آلمان', 'دانشگاه فنی مونیخ'],
      verificationTier: SourceVerificationTier.accreditedUniversity,
      isEnabled: true,
      interval: MonitoringInterval.every12Hours,
      lastCheckedAt: DateTime.now().subtract(const Duration(hours: 13)),
      nextScheduledCheckAt: DateTime.now().subtract(
        const Duration(hours: 1),
      ), // Overdue & Failed
      connectionStatus: 'timeout',
      retryAttempts: 2,
      lastErrorMessage: 'ارتباط با سرور دانشگاه به دلیل وقفه زمانی برقرار نشد (Connection Timeout).',
    ),
    ManagedResearchSource(
      id: 'src-ca-vancouver-employers',
      name: 'پورتال کارفرمایی جذب نیروی متخصص فناوری ونکوور (BC Tech Portal)',
      baseUrl: 'https://www.welcomebc.ca/Immigrate-to-B-C/BC-PNP-Tech',
      countryCode: 'CA',
      topic: 'فرصت‌های شغلی و نامزدی استانی بریتیش کلمبیا',
      relevantArticles: ['برنامه تک بریتیش کلمبیا (BC Tech PNP)'],
      verificationTier: SourceVerificationTier.employerDefinedUnverified,
      isEnabled: true,
      interval: MonitoringInterval.daily,
      lastCheckedAt: DateTime.now().subtract(const Duration(hours: 8)),
      nextScheduledCheckAt: DateTime.now().add(const Duration(hours: 16)),
      connectionStatus: 'ok_200',
    ),
    ManagedResearchSource(
      id: 'src-de-daad-iran',
      name: 'پایگاه راهنمای بورسیه دااد (DAAD Regional Guide)',
      baseUrl:
          'https://www.daad-iran.org/fa/find-funding/scholarship-database/',
      countryCode: 'DE',
      topic: 'بورسیه‌های تحقیقاتی دکتری و فرصت مطالعاتی',
      relevantArticles: ['بورسیه‌های تحصیلی دااد آلمان'],
      verificationTier: SourceVerificationTier.employerDefinedUnverified,
      isEnabled: false,
      interval: MonitoringInterval.weekly,
      lastCheckedAt: DateTime.now().subtract(const Duration(days: 8)),
      nextScheduledCheckAt: DateTime.now().subtract(
        const Duration(days: 1),
      ), // Overdue & Error
      connectionStatus: 'http_503',
      retryAttempts: 3,
      lastErrorMessage:
          'سرویس‌دهنده پاسخ ۵۰۳ (Service Temporarily Unavailable) بازگرداند.',
    ),
  ];

  List<ManagedResearchSource> getManagedSources() =>
      List.unmodifiable(_sources);
  List<ManagedResearchSource> listManagedSources() => getManagedSources();

  void toggleSourceEnabled(String id) {
    final idx = _sources.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final old = _sources[idx];
      _sources[idx] = ManagedResearchSource(
        id: old.id,
        name: old.name,
        baseUrl: old.baseUrl,
        countryCode: old.countryCode,
        universityName: old.universityName,
        topic: old.topic,
        relevantArticles: old.relevantArticles,
        verificationTier: old.verificationTier,
        isEnabled: !old.isEnabled,
        interval: old.interval,
        lastCheckedAt: old.lastCheckedAt,
        nextScheduledCheckAt: old.nextScheduledCheckAt,
        connectionStatus: old.connectionStatus,
        retryAttempts: old.retryAttempts,
        lastErrorMessage: old.lastErrorMessage,
      );
    }
  }

  void updateSourceInterval(String id, MonitoringInterval interval) {
    final idx = _sources.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final old = _sources[idx];
      _sources[idx] = ManagedResearchSource(
        id: old.id,
        name: old.name,
        baseUrl: old.baseUrl,
        countryCode: old.countryCode,
        universityName: old.universityName,
        topic: old.topic,
        relevantArticles: old.relevantArticles,
        verificationTier: old.verificationTier,
        isEnabled: old.isEnabled,
        interval: interval,
        lastCheckedAt: old.lastCheckedAt,
        nextScheduledCheckAt: DateTime.now().add(switch (interval) {
          MonitoringInterval.every6Hours => const Duration(hours: 6),
          MonitoringInterval.every12Hours => const Duration(hours: 12),
          MonitoringInterval.daily => const Duration(hours: 24),
          MonitoringInterval.weekly => const Duration(days: 7),
        }),
        connectionStatus: old.connectionStatus,
        retryAttempts: old.retryAttempts,
        lastErrorMessage: old.lastErrorMessage,
      );
    }
  }

  // Screen 3 & 4: Change Proposals
  final List<AdminSourceChangeProposal> _proposals = [
    // Proposal 1: Realistic Long Persian Article with multiple sections, table & diffs
    AdminSourceChangeProposal(
      id: 'prop-ca-fswp-001',
      revision: 4,
      targetArticleId: 'art-ca-express-entry',
      baseRevision: 3,
      authorityId: 'auth-ircc',
      authorityName: 'اداره مهاجرت، پناهندگی و شهروندی کانادا (IRCC)',
      authorityDomain: 'canada.ca',
      evidenceUrl: 'https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/express-entry/documents/proof-funds.html',
      countryCode: 'CA',
      pathwaySlug: 'express-entry-fswp',
      detectedAt: DateTime.now().subtract(const Duration(hours: 2)),
      factualStatus: FactualStatus.verified,
      reviewStatus: SourceProposalReviewStatus.pending,
      previousText: 'حداقل تمکن مالی متقاضی مجرد ۱۳,۷۵۷ دلار کانادا بود.',
      proposedText: 'طبق به‌روزرسانی جدول هزینه زندگی سال ۲۰۲۶، حداقل تمکن مالی متقاضی مجرد به ۱۴,۶۹۰ دلار کانادا افزایش یافته است.',
      summaryOfChanges: 'ویزای کاری اسکیلد ورکر فدرال کانادا (Express Entry FSWP) — افزایش تمکن مالی و جدول جدید CLB زبان',
      reviewerNotes: 'نیازمند بررسی هماهنگ با مقالات استانی PNP',
      changes: [
        // Modified Section 1: Language CLB Table
        SectionChange(
          sectionId: 'sec-language-table',
          operation: 'replace',
          claimIds: const ['claim-clb-score'],
          replacement: ArticleSectionInput(
            id: 'sec-language-table',
            anchor: 'language-requirements',
            heading: 'معیار نمرات زبان و جدول هم‌ارزی CLB',
            order: 2,
            blocks: [
              const ContentBlock(
                id: 'b-lang-intro',
                type: 'paragraph',
                text: 'متقاضیان مسیر نیروی متخصص فدرال (FSWP) موظف به کسب حداقل سطح ۷ در سامانه معیار زبان کانادایی (CLB) در کلیه مهارت‌های چهارگانه هستند.',
                items: [],
              ),
              const ContentBlock(
                id: 'b-lang-table',
                type: 'paragraph',
                text: '| مهارت زبانی | آیلتس جنرال (IELTS) | سلپیپ (CELPIP) | سطح معادل CLB |\n|---|---|---|---|\n| خواندن (Reading) | ۶.۰ | ۷ | CLB 7 |\n| نوشتن (Writing) | ۶.۰ | ۷ | CLB 7 |\n| شنیدن (Listening) | ۶.۰ | ۷ | CLB 7 |\n| صحبت کردن (Speaking) | ۶.۰ | ۷ | CLB 7 |\n| زبان دوم (فرانسوی TEF) | NCLC 5+ | NCLC 5+ | امتیاز مازاد تا ۵۰ پوئن |',
                items: [],
              ),
            ],
            evidenceRefs: const [
              EvidenceInput(
                snapshotId: 'snap-lang-2026',
                claimId: 'claim-clb-score',
                excerpt: 'To qualify for the Federal Skilled Worker Program, you must meet the minimum language level of Canadian Language Benchmark (CLB) 7 in all 4 language abilities.',
                locator: 'IRCC Operational Instructions > Language Tests > CLB 7 Matrix',
              ),
            ],
          ),
        ),
        // Modified Section 2: Proof of Funds
        SectionChange(
          sectionId: 'sec-funds',
          operation: 'replace',
          claimIds: const ['claim-proof-funds'],
          replacement: ArticleSectionInput(
            id: 'sec-funds',
            anchor: 'proof-of-funds',
            heading: 'حداقل تمکن مالی مورد نیاز سال ۲۰۲۶',
            order: 3,
            blocks: [
              const ContentBlock(
                id: 'b-funds-1',
                type: 'paragraph',
                text: 'متقاضیانی که فاقد پیشنهاد شغلی معتبر (LMIA-backed Job Offer) هستند، باید تمکن مالی معتبر بانکی بر اساس تعداد اعضای خانواده ارائه دهند. این مبالغ سالانه توسط اداره مهاجرت کانادا بازبینی می‌شود.',
                items: [],
              ),
              const ContentBlock(
                id: 'b-funds-table',
                type: 'paragraph',
                text: '| تعداد افراد خانواده | حداقل تمکن مالی (دلار کانادا) | معادل تقریبی ریالی |\n|---|---|---|\n| متقاضی مجرد (۱ نفر) | ۱۴,۶۹۰ CAD | ۱,۰۲۸,۰۰۰,۰۰۰ تومان |\n| خانواده ۲ نفره | ۱۸,۲۸۸ CAD | ۱,۲۸۰,۰۰۰,۰۰۰ تومان |\n| خانواده ۳ نفره | ۲۲,۴۸۳ CAD | ۱,۵۷۳,۰۰۰,۰۰۰ تومان |\n| خانواده ۴ نفره | ۲۷,۲۹۷ CAD | ۱,۹۱۰,۰۰۰,۰۰۰ تومان |',
                items: [],
              ),
              const ContentBlock(
                id: 'b-funds-notes',
                type: 'bullet_list',
                text: 'نکات مهم در خصوص ارائه نامه تمکن:',
                items: [
                  'نامه تمکن و گردش حساب ۶ ماهه باید روی سربرگ رسمی بانک صادر شده باشد.',
                  'حساب بانکی باید به نام شخص متقاضی اصلی یا همسر وی باشد.',
                  'سپرده‌های غیرقابل برداشت یا املاک به عنوان تمکن جاری پذیرفته نمی‌شوند.',
                ],
              ),
            ],
            evidenceRefs: const [
              EvidenceInput(
                snapshotId: 'snap-funds-2026',
                claimId: 'claim-proof-funds',
                excerpt: 'For 2026, the minimum funds required for a single applicant is \$14,690 CAD. Funds must be readily available and unencumbered by debts.',
                locator: 'IRCC Policy Manual > Table of Low Income Cut-Off (LICO) > Proof of Funds 2026',
              ),
            ],
          ),
        ),
        // Added Section 3: Biometric Requirement
        SectionChange(
          sectionId: 'sec-biometrics',
          operation: 'add',
          claimIds: const ['claim-biometric'],
          replacement: ArticleSectionInput(
            id: 'sec-biometrics',
            anchor: 'biometrics-requirement',
            heading: 'الزام ثبت اطلاعات بیومتریک (اثر انگشت و چهره‌نگاری)',
            order: 4,
            blocks: [
              const ContentBlock(
                id: 'b-bio-1',
                type: 'paragraph',
                text: 'کلیه متقاضیان ایرانی بالای ۱۴ سال و زیر ۷۹ سال موظف هستند پس از دریافت نامه Biometric Instruction Letter (BIL)، ظرف حداکثر ۳۰ روز در یکی از مراکز رسمی VAC (نظیر استانبول، آنکارا، ایروان یا دبی) حضور یافته و مشخصات بیومتریک خود را ثبت نمایند.',
                items: [],
              ),
            ],
            evidenceRefs: const [
              EvidenceInput(
                snapshotId: 'snap-bio-2026',
                claimId: 'claim-biometric',
                excerpt: 'Applicants between ages 14 and 79 must provide biometrics at a designated Visa Application Centre within 30 days of receiving their instruction letter.',
                locator: 'IRCC Biometrics Directives 2026',
              ),
            ],
          ),
        ),
        // Removed Section 4: Deprecated COVID-19 PCR Test
        SectionChange(
          sectionId: 'sec-covid-rules',
          operation: 'remove',
          claimIds: const ['claim-covid-removal'],
          replacement: null,
        ),
      ],
      evidence: [
        EvidenceRef(
          sourceDocumentId: 'doc-ircc-funds-2026',
          snapshotId: 'snap-funds-2026',
          url: 'https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/express-entry/documents/proof-funds.html',
          publisher: 'اداره مهاجرت، پناهندگی و شهروندی کانادا (IRCC)',
          sourceClass: 'official_primary',
          authorityId: 'auth-ircc',
          excerpt: 'Effective November 1, 2026: The funds needed for Express Entry candidates have been revised according to the updated 50% minimum cut-off calculation.',
          locator: 'Canada Gazette Part I / Official Proof of Funds Table',
          fetchedAt: DateTime.now().subtract(const Duration(hours: 4)),
          verifiedAt: DateTime.now().subtract(const Duration(hours: 3)),
          freshUntil: DateTime.now().add(const Duration(days: 30)),
          verificationState: FactualStatus.verified,
          freshnessState: 'live',
        ),
      ],
    ),

    // Proposal 2: Single Changed Paragraph (Germany Student Visa)
    AdminSourceChangeProposal(
      id: 'prop-de-student-002',
      revision: 2,
      targetArticleId: 'art-de-student-visa',
      baseRevision: 1,
      authorityId: 'auth-auswaertiges',
      authorityName: 'وزارت امور خارجه آلمان (Auswärtiges Amt)',
      authorityDomain: 'auswaertiges-amt.de',
      evidenceUrl: 'https://www.auswaertiges-amt.de/de/sperrkonto-studium',
      countryCode: 'DE',
      pathwaySlug: 'germany-student-blocked-account',
      detectedAt: DateTime.now().subtract(const Duration(hours: 8)),
      factualStatus: FactualStatus.verified,
      reviewStatus: SourceProposalReviewStatus.pending,
      previousText: 'مبلغ حساب مسدودشده (Sperrkonto) معادل ۹۳۴ یورو در ماه (۱۱,۲۰۸ یورو سالانه) است.',
      proposedText: 'بر اساس مصوبه جدید سال ۲۰۲۶، حداقل مبلغ ودیعه ماهانه در حساب مسدودشده دانشجویی آلمان به ۹۹۲ یورو در ماه (معادل ۱۱,۹۰۴ یورو در سال) افزایش یافت.',
      summaryOfChanges: 'ویزای دانشجویی آلمان — افزایش حداقل موجودی حساب مسدودشده بانکی (Sperrkonto) به ۹۹۲ یورو در ماه',
      changes: [
        SectionChange(
          sectionId: 'sec-de-sperrkonto',
          operation: 'replace',
          claimIds: const ['claim-de-sperrkonto'],
          replacement: ArticleSectionInput(
            id: 'sec-de-sperrkonto',
            anchor: 'blocked-account',
            heading: 'حساب مسدودشده بانکی (Sperrkonto) و تمکن مالی دانشجویی',
            order: 2,
            blocks: [
              const ContentBlock(
                id: 'b-de-sperr-1',
                type: 'paragraph',
                text: 'دانشجویان بین‌المللی برای دریافت روادید تحصیلی آلمان باید تمکن مالی خود را از طریق افتتاح حساب مسدودشده (Sperrkonto) در یکی از ارائه‌دهندگان معتبر (مانند Fintiba یا Expatrio) اثبات نمایند. حداقل رقم مصوب از ماه اکتبر ۲۰۲۶ معادل ۹۹۲ یورو برای هر ماه اقامت (سالانه ۱۱,۹۰۴ یورو) تعیین شده است.',
                items: [],
              ),
            ],
            evidenceRefs: const [
              EvidenceInput(
                snapshotId: 'snap-de-sperr-2026',
                claimId: 'claim-de-sperrkonto',
                excerpt: 'Voraussichtlich ab 01.10.2026 beträgt der monاتliche BAföG-Höchstsatz und damit der Regelsatz für das Sperrkonto 992 Euro (11.904 Euro pro Jahr).',
                locator: 'Auswärtiges Amt > Visabestimmungen > Sperrkonto 2026',
              ),
            ],
          ),
        ),
      ],
      evidence: [
        EvidenceRef(
          sourceDocumentId: 'doc-de-sperr',
          snapshotId: 'snap-de-sperr-2026',
          url: 'https://www.auswaertiges-amt.de/de/sperrkonto-studium',
          publisher: 'وزارت امور خارجه جمهوری فدرال آلمان',
          sourceClass: 'official_primary',
          authorityId: 'auth-auswaertiges',
          excerpt: 'Der geforderte Betrag im Sperrkonto für Studienvisa steigt auf 992 Euro monatlich.',
          fetchedAt: DateTime.now().subtract(const Duration(hours: 10)),
          verificationState: FactualStatus.verified,
          freshnessState: 'live',
        ),
      ],
    ),

    // Proposal 3: Conflicting Official Sources (Australia Subclass 485)
    AdminSourceChangeProposal(
      id: 'prop-au-grad-003',
      revision: 3,
      targetArticleId: 'art-au-subclass-485',
      baseRevision: 2,
      authorityId: 'auth-au-homeaffairs',
      authorityName: 'وزارت امور داخلی استرالیا',
      authorityDomain: 'immi.homeaffairs.gov.au',
      evidenceUrl: 'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-listing/temporary-graduate-485',
      countryCode: 'AU',
      pathwaySlug: 'temporary-graduate-485',
      detectedAt: DateTime.now().subtract(const Duration(hours: 18)),
      factualStatus: FactualStatus.conflicting, // Explicit Conflict!
      reviewStatus: SourceProposalReviewStatus.pending,
      previousText:
          'حداکثر سن مجاز برای دریافت ویزای فارغ‌التحصیلی ۵۰ سال تمام بود.',
      proposedText: 'مقررات جدید فدرال سقف سنی را به ۳۵ سال کاهش داده، اما کمیسیون ایالتی ویکتوریا برای فارغ‌التحصیلان دوره تحقیقاتی ارشد و دکتری استثنای ۵۰ سال قائل شده است.',
      summaryOfChanges: 'ویزای فارغ‌التحصیلی ۴۸۵ استرالیا — مغایرت در سقف سن مجاز متقاضیان دوره‌های پژوهشی',
      changes: [
        SectionChange(
          sectionId: 'sec-au-age-limit',
          operation: 'replace',
          claimIds: const ['claim-au-age-conflict'],
          replacement: ArticleSectionInput(
            id: 'sec-au-age-limit',
            anchor: 'age-eligibility',
            heading: 'شرایط سنی متقاضیان ویزای فارغ‌التحصیلی ساب‌کلاس ۴۸۵',
            order: 2,
            blocks: [
              const ContentBlock(
                id: 'b-au-age-1',
                type: 'paragraph',
                text: 'طبق دستورالعمل فدرال استرالیا، متقاضیان باید در زمان ثبت درخواست کمتر از ۳۵ سال سن داشته باشند. با این حال، بر اساس مصوبه تکمیلی مهاجرت ایالتی، متقاضیان دوره‌های کارشناسی ارشد پژوهشی (Master by Research) و دکتری (PhD) همچنان تا سن ۵۰ سالگی امکان درخواست دارند.',
                items: [],
              ),
            ],
            evidenceRefs: const [
              EvidenceInput(
                snapshotId: 'snap-au-conflict-1',
                claimId: 'claim-au-age-conflict',
                excerpt: 'Source A (Federal): Age eligibility reduced to 35 years or under at time of application. Source B (State Exemption): Doctoral and Masters by Research graduates remain eligible up to 50 years.',
                locator: 'Australian Migration Amendment Regulations 2026 / State Directives',
              ),
            ],
          ),
        ),
      ],
      evidence: [
        EvidenceRef(
          sourceDocumentId: 'doc-au-fed',
          snapshotId: 'snap-au-conflict-1',
          url: 'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-listing/temporary-graduate-485',
          publisher: 'Department of Home Affairs (Federal Authority)',
          sourceClass: 'official_primary',
          authorityId: 'auth-au-homeaffairs',
          excerpt: 'Applicants must be 35 years of age or under at the time of application.',
          fetchedAt: DateTime.now().subtract(const Duration(hours: 19)),
          verificationState: FactualStatus.conflicting,
          freshnessState: 'live',
        ),
      ],
    ),

    // Proposal 4: University Scholarship (University of Toronto)
    AdminSourceChangeProposal(
      id: 'prop-ca-uoft-004',
      revision: 1,
      targetArticleId: 'art-ca-uoft-scholarships',
      baseRevision: 1,
      authorityId: 'src-ca-uoft',
      authorityName: 'دانشگاه تورنتو (University of Toronto)',
      authorityDomain: 'future.utoronto.ca',
      evidenceUrl: 'https://future.utoronto.ca/pearson-scholarship',
      countryCode: 'CA',
      pathwaySlug: 'uoft-pearson-scholarship',
      detectedAt: DateTime.now().subtract(const Duration(days: 1)),
      factualStatus: FactualStatus.verified,
      reviewStatus: SourceProposalReviewStatus.pending,
      previousText: 'مهلت معرفی نامزدهای بورسیه ۳۰ نوامبر بود.',
      proposedText: 'مهلت ثبت‌نام مدرسه برای معرفی نامزدها تا ۱۵ دسامبر و مهلت ارسال پرونده دانشجو تا ۱۵ ژانویه تمدید گردید.',
      summaryOfChanges: 'بورسیه لستر بی پیرسون دانشگاه تورنتو — تمدید مهلت ثبت‌نام و شرایط معافیت شهریه',
      changes: [
        SectionChange(
          sectionId: 'sec-uoft-deadlines',
          operation: 'replace',
          claimIds: const ['claim-uoft-deadline'],
          replacement: ArticleSectionInput(
            id: 'sec-uoft-deadlines',
            anchor: 'scholarship-deadlines',
            heading: 'تقویم زمانی و آخرین مهلت ثبت‌نام بورسیه پیرسون',
            order: 2,
            blocks: [
              const ContentBlock(
                id: 'b-uoft-1',
                type: 'paragraph',
                text: 'متقاضیان بورسیه فول‌فاند لستر بی پیرسون دانشگاه تورنتو باید از طریق معرفی‌نامه دبیرستان خود اقدام کنند. آخرین مهلت معرفی توسط مدرسه ۱۵ دسامبر و مهلت نهایی تکمیل مدارک متقاضی در سامانه دانشگاه ۱۵ ژانویه است.',
                items: [],
              ),
            ],
            evidenceRefs: const [],
          ),
        ),
      ],
      evidence: [
        EvidenceRef(
          sourceDocumentId: 'doc-uoft-pearson',
          snapshotId: 'snap-uoft-2026',
          url: 'https://future.utoronto.ca/pearson-scholarship',
          publisher: 'University of Toronto International Admissions',
          sourceClass: 'official_primary',
          authorityId: 'src-ca-uoft',
          excerpt: 'School nomination deadline: December 15. Student application deadline: January 15.',
          fetchedAt: DateTime.now().subtract(const Duration(days: 1)),
          verificationState: FactualStatus.verified,
          freshnessState: 'live',
        ),
      ],
    ),
  ];

  // Screen 4: Related Articles Impact
  List<ArticleRelatedImpact> getRelatedArticlesImpact(String proposalId) {
    if (proposalId.contains('ca-fswp')) {
      return const [
        ArticleRelatedImpact(
          articleId: 'art-ca-pnp',
          title: 'برنامه‌های نامزدی استانی کانادا (PNP)',
          countryCode: 'CA',
          category: 'اقامت کاری و استانی',
          impactReason: 'اکثر استان‌ها (مانند انتاریو و ساسکاچوان) جدول تمکن مالی خود را مستقیماً با آستانه فدرال LICO هماهنگ می‌کنند.',
        ),
        ArticleRelatedImpact(
          articleId: 'art-ca-pgwp',
          title: 'ویزای کار پس از تحصیل کانادا (PGWP)',
          countryCode: 'CA',
          category: 'کاری فارغ‌التحصیلان',
          impactReason: 'تغییر معیار CLB بر الزامات تبدیل ویزای موقت فارغ‌التحصیلی به اقامت دائم اکسپرس اینتری تأثیر مستقیم دارد.',
        ),
      ];
    }
    return const [];
  }

  // Screen 5: Research History Records
  final List<CrawlRunHistoryItem> _crawlHistory = [
    CrawlRunHistoryItem(
      runId: 'RUN-20261028-03',
      startedAt: DateTime.now().subtract(const Duration(minutes: 24)),
      duration: const Duration(minutes: 4, seconds: 12),
      sourcesScanned: 18,
      changesFound: 2,
      failuresCount: 0,
      status: 'completed',
    ),
    CrawlRunHistoryItem(
      runId: 'RUN-20261028-02',
      startedAt: DateTime.now().subtract(const Duration(hours: 12)),
      duration: const Duration(minutes: 5, seconds: 48),
      sourcesScanned: 18,
      changesFound: 1,
      failuresCount: 1,
      status: 'partial_failure',
    ),
    CrawlRunHistoryItem(
      runId: 'RUN-20261027-01',
      startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      duration: const Duration(minutes: 3, seconds: 55),
      sourcesScanned: 16,
      changesFound: 4,
      failuresCount: 0,
      status: 'completed',
    ),
    CrawlRunHistoryItem(
      runId: 'RUN-20261026-02',
      startedAt: DateTime.now().subtract(const Duration(days: 2)),
      duration: const Duration(minutes: 6, seconds: 10),
      sourcesScanned: 16,
      changesFound: 0,
      failuresCount: 0,
      status: 'completed',
    ),
  ];

  List<CrawlRunHistoryItem> getCrawlHistory() =>
      List.unmodifiable(_crawlHistory);
  List<CrawlRunHistoryItem> listCrawlRuns() => getCrawlHistory();

  final List<SourceSnapshotItem> _snapshots = [
    SourceSnapshotItem(
      snapshotId: 'snap-funds-2026',
      authorityName: 'اداره مهاجرت، پناهندگی و شهروندی کانادا (IRCC)',
      url: 'https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/express-entry/documents/proof-funds.html',
      fetchedAt: DateTime.now().subtract(const Duration(hours: 4)),
      contentHash:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      excerpt: '<div class="table-responsive"><table class="table"><caption>Proof of funds 2026</caption><thead><tr><th>Number of family members</th><th>Funds required (in CAD)</th></tr></thead><tbody><tr><td>1</td><td>\$14,690</td></tr><tr><td>2</td><td>\$18,288</td></tr></tbody></table></div>',
      byteSize: 42180,
      httpStatusCode: 200,
    ),
    SourceSnapshotItem(
      snapshotId: 'snap-de-sperr-2026',
      authorityName: 'وزارت امور خارجه آلمان (Auswärtiges Amt)',
      url: 'https://www.auswaertiges-amt.de/de/sperrkonto-studium',
      fetchedAt: DateTime.now().subtract(const Duration(hours: 10)),
      contentHash:
          '7d793037a0760186574b0282f2f435e70d73a4e04d3eef92e6d60f9b50073038',
      excerpt: '<p class="lead">Voraussichtlich ab 01.10.2026 beträgt der monatliche BAföG-Höchstsatz und damit der Regelsatz für das Sperrkonto 992 Euro (11.904 Euro pro Jahr).</p>',
      byteSize: 31200,
      httpStatusCode: 200,
    ),
    SourceSnapshotItem(
      snapshotId: 'snap-au-conflict-1',
      authorityName: 'وزارت امور داخلی استرالیا',
      url: 'https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-listing/temporary-graduate-485',
      fetchedAt: DateTime.now().subtract(const Duration(hours: 19)),
      contentHash:
          '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
      excerpt: '<div class="alert alert-warning"><p>From 1 July 2024, applicants for the Temporary Graduate visa must be 35 years of age or under. Exemption applies for Hong Kong/BNO passport holders and select doctoral graduates.</p></div>',
      byteSize: 58940,
      httpStatusCode: 200,
    ),
  ];

  List<SourceSnapshotItem> getSourceSnapshots() =>
      List.unmodifiable(_snapshots);
  List<SourceSnapshotItem> listSourceSnapshots() => getSourceSnapshots();

  final List<AdminDecisionHistoryItem> _decisionHistory = [
    AdminDecisionHistoryItem(
      id: 'dec-20261027-01',
      proposalId: 'prop-ca-crs-oct',
      articleTitle: 'امتیازات اکسپرس اینتری و مدارک سوابق کاری کانادا',
      decision: 'approved',
      reviewerName: 'سردبیر ارشد مهاجرت (مهرداد رضایی)',
      reviewedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      reviewerNotes: 'تغییرات امتیاز کتگوری زبان فرانسوی با رفرنس رسمی IRCC مطابقت دارد. پیش‌نویس برای نگارش v4 ذخیره گردید.',
      resultingRevisionHash:
          'a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0',
    ),
    AdminDecisionHistoryItem(
      id: 'dec-20261026-02',
      proposalId: 'prop-uk-salary-threshold',
      articleTitle: 'ویزای کاری ماهر بریتانیا (UK Skilled Worker)',
      decision: 'edited_and_approved',
      reviewerName: 'کارشناس تطبیق قوانین (سارا احمدی)',
      reviewedAt: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
      reviewerNotes: 'متن فارسی توسط بازبین بازنویسی شد تا استثنائات کدهای شغلی بهداشت و درمان (Health & Care) به تفکیک درج گردد.',
      resultingRevisionHash:
          '9876543210abcdef0123456789abcdef0123456789abcdef0123456789abcdef1',
    ),
    AdminDecisionHistoryItem(
      id: 'dec-20261025-01',
      proposalId: 'prop-de-chancenkarte-rumor',
      articleTitle: 'کارت شانس آلمان (Opportunity Card)',
      decision: 'rejected',
      reviewerName: 'سردبیر ارشد مهاجرت (مهرداد رضایی)',
      reviewedAt: DateTime.now().subtract(const Duration(days: 3)),
      reviewerNotes: 'منبع ادعایی مربوط به وبلاگ مهاجرتی غیررسمی بوده و هنوز مصوبه قانون‌گذاری در بوندس‌رات منتشر نشده است.',
      resultingRevisionHash: '',
    ),
  ];

  List<AdminDecisionHistoryItem> getDecisionHistory() =>
      List.unmodifiable(_decisionHistory);
  List<AdminDecisionHistoryItem> listAdminDecisions() => getDecisionHistory();

  // Implementation of AdminCmsRepository interface methods:

  @override
  Future<List<AdminSourceChangeProposal>> listProposals() async {
    return List.unmodifiable(_proposals);
  }

  @override
  Future<AdminSourceChangeProposal?> getProposalDetail(
    String proposalId,
  ) async {
    try {
      return _proposals.firstWhere((p) => p.id == proposalId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> reviewProposal({
    required String proposalId,
    required int expectedRevision,
    required SourceProposalReviewStatus decision,
    String? reviewerNotes,
  }) async {
    final idx = _proposals.indexWhere((p) => p.id == proposalId);
    if (idx != -1) {
      final old = _proposals[idx];
      _proposals[idx] = AdminSourceChangeProposal(
        id: old.id,
        revision: old.revision + 1,
        targetArticleId: old.targetArticleId,
        baseRevision: old.baseRevision,
        authorityId: old.authorityId,
        authorityName: old.authorityName,
        authorityDomain: old.authorityDomain,
        evidenceUrl: old.evidenceUrl,
        countryCode: old.countryCode,
        pathwaySlug: old.pathwaySlug,
        detectedAt: old.detectedAt,
        factualStatus: old.factualStatus,
        reviewStatus: decision,
        previousText: old.previousText,
        proposedText: old.proposedText,
        summaryOfChanges: old.summaryOfChanges,
        reviewerNotes: reviewerNotes ?? old.reviewerNotes,
        changes: old.changes,
        evidence: old.evidence,
      );
      return true;
    }
    return false;
  }

  @override
  Future<List<Authority>> listOfficialAuthorities({
    String? countryCode,
    String? topic,
    String? state,
  }) async {
    return [
      const Authority(
        id: 'auth-ircc',
        name: 'اداره مهاجرت، پناهندگی و شهروندی کانادا (IRCC)',
        authorityType: 'government',
        countryCode: 'CA',
        jurisdiction: 'Federal Government of Canada',
        competenceTopics: ['immigration', 'visas', 'citizenship'],
        officialDomains: ['canada.ca', 'cic.gc.ca'],
        verificationState: 'verified',
        verificationRevision: 1,
      ),
      const Authority(
        id: 'auth-auswaertiges',
        name: 'وزارت امور خارجه آلمان (Auswärtiges Amt)',
        authorityType: 'government',
        countryCode: 'DE',
        jurisdiction: 'Federal Republic of Germany',
        competenceTopics: ['visas', 'study', 'chancenkarte'],
        officialDomains: ['auswaertiges-amt.de'],
        verificationState: 'verified',
        verificationRevision: 1,
      ),
      const Authority(
        id: 'auth-au-homeaffairs',
        name: 'وزارت امور داخلی استرالیا (Home Affairs)',
        authorityType: 'government',
        countryCode: 'AU',
        jurisdiction: 'Commonwealth of Australia',
        competenceTopics: ['general_skilled_migration', 'student_visa'],
        officialDomains: ['homeaffairs.gov.au'],
        verificationState: 'verified',
        verificationRevision: 1,
      ),
      const Authority(
        id: 'auth-uk-homeoffice',
        name: 'وزارت کشور بریتانیا (UK Home Office & UKVI)',
        authorityType: 'government',
        countryCode: 'UK',
        jurisdiction: 'United Kingdom',
        competenceTopics: ['skilled_worker', 'student_route'],
        officialDomains: ['gov.uk'],
        verificationState: 'verified',
        verificationRevision: 1,
      ),
    ];
  }

  @override
  Future<List<AdminCmsArticleListItem>> listCmsArticles() async {
    return [
      AdminCmsArticleListItem(
        id: 'art-ca-express-entry',
        slug: 'express-entry-fswp',
        locale: 'fa',
        countryCode: 'CA',
        countryName: 'کانادا',
        title: 'ویزای کاری و اسکیلد ورکر کانادا (Express Entry)',
        articleType: SearchArticleType.canonicalPathway,
        factualStatus: FactualStatus.verified,
        editorialStatus: ArticleEditorialStatus.published,
        lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
        authorityDomain: 'canada.ca',
      ),
      AdminCmsArticleListItem(
        id: 'art-de-student-visa',
        slug: 'germany-student-blocked-account',
        locale: 'fa',
        countryCode: 'DE',
        countryName: 'آلمان',
        title: 'ویزای دانشجویی و تمکن مالی آلمان',
        articleType: SearchArticleType.canonicalPathway,
        factualStatus: FactualStatus.verified,
        editorialStatus: ArticleEditorialStatus.published,
        lastUpdated: DateTime.now().subtract(const Duration(days: 4)),
        authorityDomain: 'auswaertiges-amt.de',
      ),
      AdminCmsArticleListItem(
        id: 'art-au-subclass-485',
        slug: 'temporary-graduate-485',
        locale: 'fa',
        countryCode: 'AU',
        countryName: 'استرالیا',
        title: 'ویزای فارغ‌التحصیلی استرالیا ساب‌کلاس ۴۸۵',
        articleType: SearchArticleType.canonicalPathway,
        factualStatus: FactualStatus.conflicting,
        editorialStatus: ArticleEditorialStatus.published,
        lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
        authorityDomain: 'homeaffairs.gov.au',
      ),
    ];
  }

  @override
  Future<CmsArticleDraft> getArticleDraft(
    String articleId, {
    String locale = 'fa',
  }) async {
    // Generate realistic multi-section base document for full article reading
    return CmsArticleDraft.fromContent(
      content: {
        'article_id': articleId,
        'locale': locale,
        'expected_revision': 3,
        'title':
            'راهنمای جامع ویزای کاری اسکیلد ورکر کانادا (Express Entry & FSWP)',
        'summary': 'کلیه شرایط، حداقل نمرات مدرک زبان، جدول تمکن مالی سال ۲۰۲۶ و مراحل گام‌به‌گام ثبت‌نام در سامانه مهاجرت کانادا.',
        'sections': [
          {
            'id': 'sec-overview',
            'anchor': 'general-overview',
            'heading':
                '۱. کلیات و الزامات عمومی برنامه نیروی متخصص فدرال (FSWP)',
            'order': 1,
            'blocks': [
              {
                'id': 'b-ov-1',
                'type': 'paragraph',
                'text': 'برنامه نیروی متخصص فدرال کانادا (Federal Skilled Worker Program) یکی از سه برنامه اصلی زیرمجموعه اکسپرس اینتری است که به متقاضیان دارای سابقه کار تخصصی، تحصیلات دانشگاهی و مهارت زبانی اجازه اخذ اقامت دائم (PR) می‌دهد.',
                'items': [],
              },
              {
                'id': 'b-ov-2',
                'type': 'paragraph',
                'text': 'متقاضیان ابتدا باید در جدول ۱۰۰ امتیازی ارزیابی اولیه، حداقل ۶۷ امتیاز لازم را کسب نمایند تا پرونده آن‌ها وارد پول (Pool) اکسپرس اینتری گردد.',
                'items': [],
              },
            ],
            'evidence_refs': [],
          },
          {
            'id': 'sec-language-table',
            'anchor': 'language-requirements',
            'heading': '۲. معیار نمرات زبان و حداقل نمره مورد نیاز (CLB)',
            'order': 2,
            'blocks': [
              {
                'id': 'b-lang-old',
                'type': 'paragraph',
                'text': 'متقاضیان در نسخه قبلی ملزم به ارائه حداقل نمره آیلتس ۶.۰ در مهارت‌های اصلی بودند و جدول معادل‌سازی CLB بر اساس ارزیابی سال ۲۰۲۲ تنظیم شده بود.',
                'items': [],
              },
            ],
            'evidence_refs': [],
          },
          {
            'id': 'sec-funds',
            'anchor': 'proof-of-funds',
            'heading': '۳. هزینه‌ها و تمکن مالی الزامی (Proof of Funds)',
            'order': 3,
            'blocks': [
              {
                'id': 'b-funds-old',
                'type': 'paragraph',
                'text': 'طبق آیین‌نامه پیشین، حداقل تمکن مالی متقاضی مجرد معادل ۱۳,۷۵۷ دلار کانادا بود که در جدول هزینه‌های زندگی سال ۲۰۲۴ ثبت شده است.',
                'items': [],
              },
            ],
            'evidence_refs': [],
          },
          {
            'id': 'sec-covid-rules',
            'anchor': 'deprecated-health',
            'heading': '۴. مقررات موقت بهداشتی و غربالگری پیش از پرواز',
            'order': 4,
            'blocks': [
              {
                'id': 'b-covid-old',
                'type': 'paragraph',
                'text': 'متقاضیان ملزم به ثبت اطلاعات واکسیناسیون در سامانه ArriveCAN و ارائه گواهی منفی تست PCR بودند. (این بند اکنون کاملاً منسوخ شده است).',
                'items': [],
              },
            ],
            'evidence_refs': [],
          },
          {
            'id': 'sec-application-process',
            'anchor': 'application-steps',
            'heading': '۵. مراحل اجرایی، دریافت دعوت‌نامه (ITA) و صدور ویزا',
            'order': 5,
            'blocks': [
              {
                'id': 'b-steps-1',
                'type': 'paragraph',
                'text': 'پس از ورود به استخر اکسپرس اینتری، پرونده بر اساس رتبه‌بندی جامع CRS سنجیده می‌شود. در صورت کسب حدنصاب در دراوهای دوره‌ای، دعوت‌نامه رسمی ITA برای متقاضی ارسال شده و وی ۶۰ روز فرصت بارگذاری مدارک نهایی را خواهد داشت.',
                'items': [],
              },
            ],
            'evidence_refs': [],
          },
        ],
        'related_article_ids': ['art-ca-pnp', 'art-ca-pgwp'],
      },
      revisionId: 'rev-003',
      contentHash: 'd41d8cd98f00b204e9800998ecf8427e',
      editorialState: ArticleEditorialStatus.published,
    );
  }

  @override
  Future<bool> saveCanonicalArticle(
    CmsArticleDraft article, {
    required String title,
    required String summary,
    List<Map<String, dynamic>>? sections,
    required String requestKey,
  }) async {
    return true;
  }

  @override
  Future<ArticleRevisionResult> submitArticleReview({
    required String articleId,
    required String revisionId,
    required int expectedRevision,
    required String contentHash,
    required String note,
    required String requestKey,
  }) async {
    return ArticleRevisionResult(
      articleId: articleId,
      revisionId: 'rev-sub-001',
      revision: expectedRevision + 1,
      contentHash: contentHash,
      editorialState: ArticleEditorialStatus.inReview,
      verificationState: FactualStatus.verified,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<ArticleRevisionResult> approveArticleRevision({
    required String articleId,
    required String revisionId,
    required int expectedRevision,
    required String contentHash,
    required String note,
    required String requestKey,
  }) async {
    return ArticleRevisionResult(
      articleId: articleId,
      revisionId: 'rev-app-001',
      revision: expectedRevision + 1,
      contentHash: contentHash,
      editorialState: ArticleEditorialStatus.approved,
      verificationState: FactualStatus.verified,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<ArticleRevisionResult> rejectArticleRevision({
    required String articleId,
    required String revisionId,
    required int expectedRevision,
    required String contentHash,
    required String note,
    required String requestKey,
  }) async {
    return ArticleRevisionResult(
      articleId: articleId,
      revisionId: 'rev-rej-001',
      revision: expectedRevision,
      contentHash: contentHash,
      editorialState: ArticleEditorialStatus.draft,
      verificationState: FactualStatus.incorrect,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<PublicationResult> publishArticleRevision({
    required String articleId,
    required String revisionId,
    required String contentHash,
    required String requestKey,
  }) async {
    return PublicationResult(
      resourceId: articleId,
      revisionId: revisionId,
      revision: 4,
      eventId: 'evt-pub-001',
      publishedAt: DateTime.now(),
      target: {'kind': 'visa_article', 'id': articleId},
    );
  }

  @override
  Future<ArticleRevisionResult> rollbackArticle({
    required String articleId,
    required String locale,
    required String fromRevisionId,
    required int expectedRevision,
    required String reason,
    required String requestKey,
  }) async {
    return ArticleRevisionResult(
      articleId: articleId,
      revisionId: 'rev-roll-001',
      revision: expectedRevision + 1,
      contentHash: 'hash-rollback',
      editorialState: ArticleEditorialStatus.approved,
      verificationState: FactualStatus.verified,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<RevisionSummary>> listArticleRevisions({
    required String articleId,
    required String locale,
  }) async {
    return [
      RevisionSummary(
        revisionId: 'rev-003',
        revision: 3,
        locale: locale,
        contentHash: 'hash-v3-head',
        editorialState: ArticleEditorialStatus.published,
        verificationState: FactualStatus.verified,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        createdBy: 'سردبیر ارشد',
      ),
      RevisionSummary(
        revisionId: 'rev-002',
        revision: 2,
        locale: locale,
        contentHash: 'hash-v2',
        editorialState: ArticleEditorialStatus.approved,
        verificationState: FactualStatus.verified,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        createdBy: 'سردبیر ارشد',
      ),
      RevisionSummary(
        revisionId: 'rev-001',
        revision: 1,
        locale: locale,
        contentHash: 'hash-v1-init',
        editorialState: ArticleEditorialStatus.published,
        verificationState: FactualStatus.verified,
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
        createdBy: 'تیم مهاجرت راد',
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> discoverOfficialAuthorities({
    required String countryCode,
    required String topic,
    String? profession,
    required String requestKey,
  }) async {
    return {'discovered_count': 3, 'status': 'queued'};
  }

  @override
  Future<Map<String, dynamic>> enqueueResearchRefresh({
    required List<String> authorityIds,
    required String requestKey,
  }) async {
    return {
      'job_id': 'job-crawl-fresh',
      'enqueued_count': authorityIds.length,
      'status': 'processing',
    };
  }

  @override
  Future<Map<String, dynamic>> approveVisaSourceInventory({
    required String articleId,
    required List<String> sourceSnapshotIds,
    required int expectedInventoryRevision,
    required String requestKey,
  }) async {
    return {'article_id': articleId, 'status': 'approved'};
  }
}

/// Provider for MockResearchAdminRepository
final mockResearchAdminRepositoryProvider =
    Provider<MockResearchAdminRepository>((ref) {
      return MockResearchAdminRepository();
    });
