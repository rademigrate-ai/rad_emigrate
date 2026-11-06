import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/admin/data/admin_cms_repository.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';
import 'package:rad_emigrate/features/admin/domain/entities/admin_cms_entities.dart';
import 'package:rad_emigrate/features/admin/presentation/pages/admin_source_monitor_page.dart';
import 'package:rad_emigrate/features/admin/presentation/widgets/research_dashboard_view.dart';

const authorityId = '10000000-0000-4000-8000-000000000001';
const authority = Authority(
  id: authorityId,
  name: 'Candidate university',
  authorityType: 'university',
  countryCode: 'CA',
  jurisdiction: 'CA',
  competenceTopics: ['study'],
  officialDomains: [],
  verificationState: 'candidate',
  verificationRevision: 1,
);

class LiveRepository implements AdminCmsRepository {
  LiveRepository(this.authorities);
  final List<Authority> authorities;
  final requests = <List<String>>[];
  @override
  Future<List<Authority>> listOfficialAuthorities({
    String? countryCode,
    String? topic,
    String? state,
  }) async => authorities;
  @override
  Future<List<AdminSourceChangeProposal>> listProposals() async => [];
  @override
  Future<Map<String, dynamic>> enqueueResearchRefresh({
    required List<String> authorityIds,
    required String requestKey,
  }) async {
    requests.add(authorityIds);
    return {'status': 'queued'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('authority inventory does not manufacture monitoring health or a completed crawl', () async {
    final container = ProviderContainer(
      overrides: [
        adminCmsRepositoryProvider.overrideWithValue(
          LiveRepository([authority]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(adminAuthoritiesProvider.future);
    await container.read(adminProposalsProvider.future);
    final metrics = container.read(adminDashboardMetricsProvider);
    expect(metrics.lastCrawlCompletedAt, isNull);
    expect(metrics.monitoringFailuresCount, isNull);
    expect(metrics.overdueSourceChecksCount, isNull);
    final source = container.read(adminManagedSourcesProvider).single;
    expect(source.lastCheckedAt, isNull);
    expect(source.nextScheduledCheckAt, isNull);
    expect(source.connectionStatus, 'unknown');
    expect(source.baseUrl, isEmpty);
    expect(source.verificationTier.name, 'employerDefinedUnverified');
  });
  testWidgets('manual dashboard crawl submits actual authority UUIDs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = LiveRepository([authority]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminCmsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminSourceMonitorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('داشبورد پایش'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پویش دستی فوری'));
    await tester.pumpAndSettle();
    expect(repo.requests, [
      [authorityId],
    ]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'missing monitoring telemetry displays unavailable and no invented country claims',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = LiveRepository([]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [adminCmsRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AdminSourceMonitorPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('داشبورد پایش'));
      await tester.pumpAndSettle();
      expect(find.text('نامشخص'), findsWidgets);
      expect(find.text('۳ مورد بحرانی'), findsNothing);
      expect(find.text('تغییر تمکن و نمرات زبان'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'پویش دستی فوری'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('تاریخچه و کپسول‌ها'));
      await tester.pumpAndSettle();
      expect(
        find.text('تاریخچه پایش و کپسول‌های منبع در دسترس نیست.'),
        findsOneWidget,
      );
      expect(find.byType(ResearchDashboardView), findsNothing);
    },
  );
}
