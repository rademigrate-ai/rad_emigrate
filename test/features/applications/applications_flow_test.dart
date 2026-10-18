import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/app_card.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';
import 'package:rad_emigrate/core/widgets/status_badge.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/features/applications/domain/repositories/application_repository.dart';
import 'package:rad_emigrate/features/applications/presentation/pages/applications_page.dart';
import 'package:rad_emigrate/features/applications/presentation/providers/application_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _FakeAppRepo implements ApplicationRepository {
  _FakeAppRepo(this.apps);
  List<VisaApplication> apps;
  int updateCalls = 0;
  int createCalls = 0;

  @override
  Future<List<VisaApplication>> listApplications({String? userId}) async =>
      apps;

  @override
  Future<VisaApplication?> getApplication(String id) async {
    for (final a in apps) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<VisaApplication> createApplication(VisaApplication application) async {
    createCalls++;
    final created = application.copyWith(id: 'app-${apps.length + 1}');
    apps = [created, ...apps];
    return created;
  }

  @override
  Future<VisaApplication> updateApplication(VisaApplication application) async {
    updateCalls++;
    apps = apps.map((a) => a.id == application.id ? application : a).toList();
    return application;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testApp1 = VisaApplication(
    id: 'app-canada-study',
    title: 'University of Toronto Permit',
    programName: 'Study Permit Canada',
    country: 'Canada',
    status: ApplicationStatus.submitted,
    updatedAt: DateTime(2026, 10, 18),
    createdAt: DateTime(2026, 10, 10),
  );

  final testApp2 = VisaApplication(
    id: 'app-germany-job',
    title: 'Opportunity Card Application',
    programName: 'Chancenkarte Germany',
    country: 'Germany',
    status: ApplicationStatus.approved,
    updatedAt: DateTime(2026, 10, 17),
    createdAt: DateTime(2026, 10, 05),
  );

  Widget createSubject({
    required SharedPreferences prefs,
    required _FakeAppRepo repo,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        applicationControllerProvider.overrideWith(
          (ref) => ApplicationController(repo, 'test-user-id'),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const ApplicationsPage(),
      ),
    );
  }

  testWidgets(
    'ApplicationsPage renders cards, status, and supports filter chips',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeAppRepo([testApp1, testApp2]);

      await tester.pumpWidget(createSubject(prefs: prefs, repo: repo));
      await tester.pumpAndSettle();

      // Verify application titles
      expect(find.text('University of Toronto Permit'), findsOneWidget);
      expect(find.text('Opportunity Card Application'), findsOneWidget);

      // Verify status labels
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);

      // Filter by 'Under review / In Progress' (chip index 1)
      final reviewingChip = find.widgetWithText(ChoiceChip, 'Under review');
      expect(reviewingChip, findsOneWidget);
      await tester.tap(reviewingChip);
      await tester.pumpAndSettle();

      // Submitted app should still be visible under non-completed filter
      expect(find.text('University of Toronto Permit'), findsOneWidget);
      // Approved app should be hidden under non-completed filter
      expect(find.text('Opportunity Card Application'), findsNothing);

      // Filter by 'Completed' (chip index 2)
      final completedChip = find.widgetWithText(ChoiceChip, 'Completed');
      expect(completedChip, findsOneWidget);
      await tester.tap(completedChip);
      await tester.pumpAndSettle();

      // Approved app should now be visible under completed filter
      expect(find.text('Opportunity Card Application'), findsOneWidget);
      expect(find.text('University of Toronto Permit'), findsNothing);
    },
  );

  testWidgets(
    'tapping an application opens detail view and allows status update',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeAppRepo([testApp1]);

      await tester.pumpWidget(createSubject(prefs: prefs, repo: repo));
      await tester.pumpAndSettle();

      // Tap application card to open detail
      final card = find.widgetWithText(AppCard, 'University of Toronto Permit');
      await tester.tap(card);
      await tester.pumpAndSettle();

      // In detail view
      expect(find.text('Study Permit Canada'), findsOneWidget);
      expect(find.byType(StatusBadge), findsOneWidget);

      // Update status to 'Under review'
      final reviewingFilterChip = find.widgetWithText(
        FilterChip,
        'Under review',
      );
      expect(reviewingFilterChip, findsOneWidget);
      await tester.tap(reviewingFilterChip);
      await tester.pumpAndSettle();

      expect(repo.updateCalls, 1);
      expect(repo.apps.first.status, ApplicationStatus.reviewing);

      // Tap back button to return to applications list
      final backBtn = find.byTooltip('Back to applications');
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Returned to list view
      expect(find.text('University of Toronto Permit'), findsOneWidget);
    },
  );

  testWidgets('creating a new draft adds draft to list', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeAppRepo([testApp1]);

    await tester.pumpWidget(createSubject(prefs: prefs, repo: repo));
    await tester.pumpAndSettle();

    final addBtn = find.byIcon(Icons.add);
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(find.text('New application draft'), findsOneWidget);
  });

  testWidgets('empty state renders EmptyState widget with new draft action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeAppRepo([]);

    await tester.pumpWidget(createSubject(prefs: prefs, repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No applications yet'), findsOneWidget);

    // Tap the empty state action button to create draft
    final actionBtn = find.widgetWithText(FilledButton, 'New draft');
    expect(actionBtn, findsOneWidget);
    await tester.tap(actionBtn);
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
  });
}
