import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/data/admin_cms_repository.dart';
import 'package:rad_emigrate/features/admin/data/mock_research_admin_repository.dart';
import 'package:rad_emigrate/features/admin/data/research_review_repository.dart';
import 'package:rad_emigrate/core/supabase/supabase_providers.dart';
import 'package:rad_emigrate/features/admin/domain/entities/admin_cms_entities.dart';
import 'package:rad_emigrate/features/admin/domain/entities/admin_research_models.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_full_page_diff_page.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_source_monitor_page.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/research_dashboard_view.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/research_history_view.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/source_management_view.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _FakeLiveEmptyAdminCmsRepository implements AdminCmsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<AdminSourceChangeProposal>> listProposals() async => const [];

  @override
  Future<List<Authority>> listOfficialAuthorities({
    String? countryCode,
    String? topic,
    String? state,
  }) async => const [];
}

class _FixtureResearchReviewRepository implements ResearchReviewRepository {
  _FixtureResearchReviewRepository(this._mock);

  final MockResearchAdminRepository _mock;

  @override
  Future<Map<String, dynamic>> context(String proposalId) async {
    final proposal = await _mock.getProposalDetail(proposalId);
    if (proposal == null) throw StateError('Unknown fixture proposal');
    final draft = await _mock.getArticleDraft(proposal.targetArticleId);
    return {
      'proposal': {
        'id': proposal.id,
        'revision': proposal.revision,
        'target_article_id': proposal.targetArticleId,
        'base_revision': proposal.baseRevision,
        'new_snapshot_id': proposal.newSnapshotId,
        'authority_id': proposal.authorityId,
        'country_code': proposal.countryCode,
        'pathway_slug': proposal.pathwaySlug,
        'created_at': proposal.detectedAt.toIso8601String(),
        'verification_state': proposal.factualStatus.name,
        'editorial_state': proposal.reviewStatus.name,
        'changes': [for (final change in proposal.changes) change.toJson()],
        'evidence': [for (final item in proposal.evidence) item.toJson()],
      },
      'base': {
        'title': draft.title,
        'related_articles': [
          for (final item in _mock.getRelatedArticlesImpact(proposalId))
            {
              'article_id': item.articleId,
              'title': item.title,
              'impact_reason': item.impactReason,
            },
        ],
        'revision_id': 'fixture-base-revision',
        'content_hash': 'fixture-base-content-hash',
        'body': {'sections': draft.rawSections},
      },
      'review_revision': 1,
      'stale': false,
      'decisions': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<Map<String, dynamic>> save({
    required Map<String, dynamic> context,
    required String mode,
    required Map<String, String> decisions,
    required Map<String, String> edits,
    required String note,
  }) async => {
    'published': false,
    'draft_revision': {'editorial_state': 'draft'},
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestContainer({
  required Widget child,
  Size screenSize = const Size(1200, 1000),
  MockResearchAdminRepository? mockRepo,
  AdminCmsRepository? customRepo,
}) {
  final repo = customRepo ?? mockRepo ?? MockResearchAdminRepository();
  return ProviderScope(
    overrides: [
      adminCmsRepositoryProvider.overrideWithValue(repo),
      if (repo is MockResearchAdminRepository)
        mockResearchAdminRepositoryProvider.overrideWithValue(repo),
      if (mockRepo != null) ...[
        researchReviewRepositoryProvider.overrideWithValue(
          _FixtureResearchReviewRepository(mockRepo),
        ),
        adminResearchActorReaderProvider.overrideWithValue(
          () => 'fixture-admin',
        ),
        supabaseAuthUserIdProvider.overrideWith(
          (ref) => Stream.value('fixture-admin'),
        ),
      ],
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fa'),
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          textScaler: const TextScaler.linear(1.0),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RAD Research Assistant — Admin UI/UX End-to-End Suite', () {
    testWidgets(
      'Screen 1 — Research Dashboard renders 8 metric cards, alert banner, countries and recent crawl activity',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockRepo = MockResearchAdminRepository();
        final metrics = mockRepo.getDashboardMetrics();
        final runs = mockRepo.getCrawlHistory();

        bool crawlTriggered = false;
        bool retryTriggered = false;

        await tester.pumpWidget(
          createTestContainer(
            child: Scaffold(
              body: ResearchDashboardView(
                metrics: metrics,
                recentRuns: runs,
                onTriggerManualCrawl: () async {
                  crawlTriggered = true;
                },
                onRetryFailedSources: () async {
                  retryTriggered = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify 8 Key Metric Stat Cards
        expect(find.text('کشورهای تحت پایش'), findsOneWidget);
        expect(find.text('مراجع رسمی فعال'), findsOneWidget);
        expect(find.text('منابع افزوده‌شده کارفرما'), findsOneWidget);
        expect(find.text('دانشگاه‌های تحت رصد'), findsOneWidget);
        expect(find.text('تغییرات محتوایی مکشوفه'), findsOneWidget);
        expect(find.text('پیشنهادهای در انتظار بررسی'), findsOneWidget);
        expect(find.text('خطاهای پایش و اتصال'), findsOneWidget);
        expect(find.text('بررسی‌های معوق (Overdue)'), findsOneWidget);

        // 2. Verify metric values
        expect(find.text('5'), findsOneWidget); // 5 countries
        expect(find.text('18'), findsOneWidget); // 18 active official sources
        expect(
          find.text('4'),
          findsWidgets,
        ); // employer sources & pending reviews
        expect(find.text('12'), findsOneWidget); // 12 universities
        expect(find.text('7'), findsOneWidget); // 7 detected changes
        expect(find.text('2'), findsOneWidget); // 2 failures
        expect(find.text('3'), findsOneWidget); // 3 overdue

        // 3. Verify Failure Alert Banner
        expect(find.textContaining('مرجع به دلیل خطای اتصال'), findsOneWidget);
        await tester.tap(find.text('تلاش مجدد مراجع ناموفق'));
        await tester.pumpAndSettle();
        expect(retryTriggered, isTrue);

        // 4. Verify Manual Crawl Trigger Button (in header at the top)
        final crawlButtonFinder = find.text('پویش دستی فوری');
        expect(crawlButtonFinder, findsOneWidget);
        await tester.tap(crawlButtonFinder);
        await tester.pumpAndSettle();
        expect(crawlTriggered, isTrue);

        // 5. Verify Monitored Countries Spotlight (scroll into view)
        final canadaFinder = find.text('کانادا (Canada)');
        await tester.ensureVisible(canadaFinder);
        await tester.pumpAndSettle();
        expect(canadaFinder, findsOneWidget);
        expect(find.text('آلمان (Germany)'), findsOneWidget);
        expect(find.text('استرالیا (Australia)'), findsOneWidget);
        expect(find.text('انگلستان (United Kingdom)'), findsOneWidget);

        // 6. Verify Human in the Loop Security Assurance Notice (scroll to bottom)
        await tester.drag(find.byType(ListView), const Offset(0, -800));
        await tester.pumpAndSettle();
        expect(find.textContaining('تضمین حاکمیت سردبیری'), findsOneWidget);
      },
    );

    testWidgets(
      'Screen 2 — Source Management verifies verification tiers, interval selector, active toggle and refresh',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockRepo = MockResearchAdminRepository();
        final sources = mockRepo.getManagedSources();

        String? toggledSourceId;
        String? intervalUpdatedSourceId;
        MonitoringInterval? newIntervalVal;
        String? refreshedSourceId;

        await tester.pumpWidget(
          createTestContainer(
            child: Scaffold(
              body: SourceManagementView(
                sources: sources,
                onToggleSource: (id) => toggledSourceId = id,
                onUpdateInterval: (id, interval) {
                  intervalUpdatedSourceId = id;
                  newIntervalVal = interval;
                },
                onRefreshSource: (id) async => refreshedSourceId = id,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Official Authorities & Universities are rendered
        expect(
          find.text('اداره مهاجرت، پناهندگی و شهروندی کانادا (IRCC)'),
          findsOneWidget,
        );

        // Search for university source to avoid ListView viewport scroll virtualization
        await tester.enterText(find.byType(TextField).first, 'تورنتو');
        await tester.pumpAndSettle();
        expect(
          find.text('پورتال رسمی پذیرش بین‌الملل دانشگاه تورنتو (U of T)'),
          findsOneWidget,
        );

        // Search for employer source
        await tester.enterText(find.byType(TextField).first, 'BC Tech');
        await tester.pumpAndSettle();
        expect(find.textContaining('BC Tech Portal'), findsOneWidget);

        // Clear search
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pumpAndSettle();

        // 2. Verify Verification Tier Badges & Provenance Badges
        expect(find.text('مرجع دولتی رسمی'), findsWidgets);
        expect(find.text('تأییدشده رسمی'), findsWidgets);

        // 3. Verify Active Switch Toggle
        final switches = find.byType(Switch);
        expect(switches, findsWidgets);
        await tester.tap(switches.first);
        await tester.pumpAndSettle();
        expect(toggledSourceId, equals('src-ca-ircc'));

        // 4. Verify Monitoring Interval Selection
        final intervalDropdowns = find.byType(
          DropdownButton<MonitoringInterval>,
        );
        expect(intervalDropdowns, findsWidgets);
        await tester.tap(intervalDropdowns.first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('هر ۶ ساعت').last);
        await tester.pumpAndSettle();
        expect(intervalUpdatedSourceId, equals('src-ca-ircc'));
        expect(newIntervalVal, equals(MonitoringInterval.every6Hours));

        // 5. Verify Manual Refresh Button
        final refreshButtons = find.text('واکشی تغییرات منبع');
        expect(refreshButtons, findsWidgets);
        await tester.tap(refreshButtons.first);
        await tester.pumpAndSettle();
        expect(refreshedSourceId, equals('src-ca-ircc'));

        // 6. Verify Filter by Country
        await tester.tap(find.text('🇨🇦 کانادا').first);
        await tester.pumpAndSettle();
        expect(
          find.text('اداره مهاجرت، پناهندگی و شهروندی کانادا (IRCC)'),
          findsOneWidget,
        );
        expect(
          find.text('وزارت امور خارجه جمهوری فدرال آلمان (Auswärtiges Amt)'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Screen 3 & 4 — Full Article Review renders continuous document, tables, dates, and live editing',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockRepo = MockResearchAdminRepository();

        await tester.pumpWidget(
          createTestContainer(
            mockRepo: mockRepo,
            child: const AdminFullPageDiffPage(sourceId: 'prop-ca-fswp-001'),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Continuous Document Reading & Headings
        expect(find.text('معیار نمرات زبان و جدول هم‌ارزی CLB'), findsWidgets);
        expect(find.text('حداقل تمکن مالی مورد نیاز سال ۲۰۲۶'), findsWidgets);

        // 2. Verify Complex Markdown Table Rendering (CLB and Proof of Funds tables)
        expect(find.text('مهارت زبانی'), findsOneWidget);
        expect(find.text('آیلتس جنرال (IELTS)'), findsOneWidget);
        expect(find.text('سطح معادل CLB'), findsOneWidget);
        expect(find.text('تعداد افراد خانواده'), findsOneWidget);
        expect(find.text('۱۴,۶۹۰ CAD'), findsOneWidget);

        // 3. Verify Official Source Attribution Box with Publication & Effective Dates
        // Stage 7 identifies proposed evidence explicitly, rather than
        // presenting it as already-authoritative legal proof.
        expect(find.textContaining('شواهد پیشنهادی'), findsWidgets);
        expect(find.textContaining('canada.ca'), findsWidgets);
        expect(find.textContaining('تاریخ انتشار منبع'), findsWidgets);

        // 4. Verify Granular Section Accept Action
        final acceptFinder = find.text('تأیید این بند').first;
        await tester.ensureVisible(acceptFinder);
        await tester.pumpAndSettle();
        await tester.tap(acceptFinder);
        await tester.pumpAndSettle();

        // 5. Verify In-Place Live Text Editing
        // Structured tables are intentionally not editable as plain text.
        // Select only the enabled edit action for a single-paragraph change.
        final editFinder = find
            .ancestor(
              of: find.text('ویرایش متن'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is OutlinedButton && widget.onPressed != null,
              ),
            )
            .first;
        await tester.scrollUntilVisible(
          editFinder,
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(editFinder);
        await tester.pumpAndSettle();

        final saveFinder = find.text('ثبت ویرایش');
        await tester.scrollUntilVisible(
          saveFinder,
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(saveFinder, findsOneWidget);

        await tester.enterText(
          find.byType(TextField).last,
          'متن ویرایش‌شده توسط سردبیر ارشد برای سال ۲۰۲۶',
        );
        await tester.tap(saveFinder);
        await tester.pumpAndSettle();

        // 6. Verify Complete Final Document Preview Mode Switcher
        final previewFinder = find.text('پیش‌نمایش سند نهایی');
        await tester.ensureVisible(previewFinder);
        await tester.pumpAndSettle();
        await tester.tap(previewFinder);
        await tester.pumpAndSettle();
        expect(
          find.text('پیش‌نمایش سند نهایی پیش‌نویس (Clean Unified Preview)'),
          findsOneWidget,
        );
        expect(
          find.textContaining('این نما سند کامل را به صورت یکپارچه'),
          findsOneWidget,
        );

        // 7. Verify Related Articles Impact Panel (scroll down)
        await tester.drag(find.byType(ListView), const Offset(0, -800));
        await tester.pumpAndSettle();
        final impactFinder = find.text(
          'مقالات مرتبط متأثر از تغییرات این منبع:',
        );
        expect(impactFinder, findsOneWidget);
        expect(
          find.text('برنامه‌های نامزدی استانی کانادا (PNP)'),
          findsOneWidget,
        );
        expect(
          find.text('ویزای کار پس از تحصیل کانادا (PGWP)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Screen 4 — Admin Decisions verifies dual-source conflict panel on conflicting proposals',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockRepo = MockResearchAdminRepository();

        await tester.pumpWidget(
          createTestContainer(
            mockRepo: mockRepo,
            child: const AdminFullPageDiffPage(sourceId: 'prop-au-grad-003'),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Conflict Callout Banner & Dual Source Claims
        expect(
          find.textContaining(
            'هشدار مغایرت: میان منابع رسمی استناد تناقض اطلاعاتی مشاهده شده است',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('مغایرت استخراج‌شده: ادعای منبع فدرال'),
          findsOneWidget,
        );

        // 2. Verify Dual Source Claims Resolution Options
        expect(find.text('اعمال استناد منبع فدرال'), findsOneWidget);
        expect(find.text('اعمال تبصره ایالتی'), findsOneWidget);
      },
    );

    testWidgets(
      'Screen 5 — Research History views crawl runs, snapshots with inspect modal, and decision logs',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockRepo = MockResearchAdminRepository();
        final runs = mockRepo.getCrawlHistory();
        final snapshots = mockRepo.getSourceSnapshots();
        final decisions = mockRepo.getDecisionHistory();

        await tester.pumpWidget(
          createTestContainer(
            child: Scaffold(
              body: ResearchHistoryView(
                crawlRuns: runs,
                snapshots: snapshots,
                decisions: decisions,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Crawl Runs Sub-Tab (default)
        expect(find.text('دوره‌های پویش (Crawl Runs)'), findsOneWidget);
        expect(find.textContaining('پویش شماره'), findsWidgets);
        expect(find.text('تکمیل‌شده'), findsWidgets);

        // 2. Snapshots Archive Sub-Tab
        await tester.tap(find.text('آرشیو تصاویر مراجع (Snapshots)'));
        await tester.pumpAndSettle();
        expect(
          find.text('اداره مهاجرت، پناهندگی و شهروندی کانادا (IRCC)'),
          findsOneWidget,
        );
        expect(
          find.text('وزارت امور خارجه آلمان (Auswärtiges Amt)'),
          findsOneWidget,
        );

        // 3. Inspect Snapshot Modal with SHA-256 Hash
        await tester.tap(find.text('مشاهده جزئیات کپسول').first);
        await tester.pumpAndSettle();
        expect(
          find.text('کپسول تصویر لحظه‌ای منبع (Source Snapshot)'),
          findsOneWidget,
        );
        expect(find.text('هش محتوا (SHA-256):'), findsOneWidget);
        expect(
          find.textContaining(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ),
          findsOneWidget,
        );
        expect(
          find.text('متن خام و استخراج‌شده از منبع رسمی:'),
          findsOneWidget,
        );

        // Close modal
        await tester.tap(find.text('بستن'));
        await tester.pumpAndSettle();

        // 4. Past Decisions Audit Log Sub-Tab
        await tester.tap(find.text('تصمیمات سردبیری (Audit Log)'));
        await tester.pumpAndSettle();
        expect(find.text('تأیید شد'), findsOneWidget);
        expect(find.text('با ویرایش تأیید شد'), findsOneWidget);
        expect(find.text('رد شد'), findsOneWidget);
        expect(find.textContaining('مهرداد رضایی'), findsWidgets);
        expect(find.textContaining('هش پیش‌نویس نگارش مصوب:'), findsWidgets);
      },
    );

    testWidgets(
      'Responsive verification — Mobile (390px) and Desktop (1200px) render without overflow',
      (tester) async {
        final mockRepo = MockResearchAdminRepository();
        final metrics = mockRepo.getDashboardMetrics();
        final runs = mockRepo.getCrawlHistory();

        // Mobile Screen: 390 x 844 (iPhone 14 / modern mobile)
        await tester.pumpWidget(
          createTestContainer(
            screenSize: const Size(390, 844),
            child: Scaffold(
              body: ResearchDashboardView(metrics: metrics, recentRuns: runs),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('داشبورد هوشمند پایش و دستیار پژوهش'), findsOneWidget);

        // Desktop Screen: 1200 x 900
        await tester.pumpWidget(
          createTestContainer(
            screenSize: const Size(1200, 900),
            child: Scaffold(
              body: ResearchDashboardView(metrics: metrics, recentRuns: runs),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('داشبورد هوشمند پایش و دستیار پژوهش'), findsOneWidget);
      },
    );

    testWidgets(
      'Complete AdminSourceMonitorPage 4-tab workflow integrates all 5 screens cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestContainer(child: const AdminSourceMonitorPage()),
        );
        await tester.pumpAndSettle();

        // Tab 0: Findings & Proposals Gateway (Screens 3 & 4)
        expect(find.text('پیشنهادهای مغایرت'), findsOneWidget);
        expect(find.text('بررسی تطبیقی تمام‌صفحه'), findsWidgets);

        // Switch to Tab 1: Dashboard (Screen 1)
        await tester.tap(find.text('داشبورد پایش'));
        await tester.pumpAndSettle();
        expect(find.text('کشورهای تحت پایش'), findsOneWidget);
        expect(find.text('مراجع رسمی فعال'), findsOneWidget);

        // Switch to Tab 2: Sources Management (Screen 2)
        await tester.tap(find.text('مراجع رسمی و معتبر'));
        await tester.pumpAndSettle();
        expect(
          find.text('اداره مهاجرت، پناهندگی و شهروندی کانادا (IRCC)'),
          findsOneWidget,
        );
        expect(find.text('واکشی تغییرات منبع'), findsWidgets);

        // Switch to Tab 3: History (Screen 5)
        await tester.tap(find.text('تاریخچه و کپسول‌ها'));
        await tester.pumpAndSettle();
        expect(find.text('دوره‌های پویش (Crawl Runs)'), findsOneWidget);
      },
    );

    testWidgets(
      'Real backend mode: when repository returns empty records, UI shows honest zero/empty state without mock fallback',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final liveRepo = _FakeLiveEmptyAdminCmsRepository();

        await tester.pumpWidget(
          createTestContainer(
            customRepo: liveRepo,
            child: const AdminSourceMonitorPage(),
          ),
        );
        await tester.pumpAndSettle();

        // Tab 0: Findings empty state
        expect(find.text('هیچ تغییر جدیدی یافت نشد.'), findsOneWidget);

        // Tab 1: Dashboard with honest 0 counts
        await tester.tap(find.text('داشبورد پایش'));
        await tester.pumpAndSettle();
        expect(find.text('کشورهای تحت پایش'), findsOneWidget);
        expect(find.text('0'), findsWidgets);

        // Tab 2: Sources Management with honest empty state (NOT mock IRCC or Auswaertiges Amt)
        await tester.tap(find.text('مراجع رسمی و معتبر'));
        await tester.pumpAndSettle();
        expect(
          find.text('هیچ مرجع یا منبعی با فیلترهای انتخابی یافت نشد.'),
          findsOneWidget,
        );
        expect(
          find.text('اداره مهاجرت، پناهندگی و شهروندی کانادا (IRCC)'),
          findsNothing,
        );

        // Tab 3: History with honest empty states
        await tester.tap(find.text('تاریخچه و کپسول‌ها'));
        await tester.pumpAndSettle();
        expect(
          find.text('هیچ دوره پویشی در سرور ثبت نشده است.'),
          findsOneWidget,
        );
      },
    );
  });
}
