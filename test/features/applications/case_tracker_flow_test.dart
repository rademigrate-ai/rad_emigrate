import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/empty_state.dart';
import 'package:rad_emigrate/features/applications/domain/entities/application_status.dart';
import 'package:rad_emigrate/features/applications/domain/entities/case_checklist.dart';
import 'package:rad_emigrate/features/applications/domain/entities/visa_application.dart';
import 'package:rad_emigrate/features/applications/domain/repositories/application_repository.dart';
import 'package:rad_emigrate/features/applications/presentation/pages/applications_page.dart';
import 'package:rad_emigrate/features/applications/presentation/providers/application_controller.dart';
import 'package:rad_emigrate/features/applications/presentation/providers/case_tracker_controller.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  final fixedClock = DateTime.utc(2026, 10, 18, 12);

  final sampleApp = VisaApplication(
    id: 'case-canada-study-001',
    userId: 'user-001',
    title: 'University of British Columbia Study Permit',
    programName: 'Canada Study Permit',
    country: 'Canada',
    status: ApplicationStatus.submitted,
    updatedAt: fixedClock,
    createdAt: fixedClock.subtract(const Duration(days: 10)),
  );

  Widget buildSubject({
    required SharedPreferences prefs,
    required _FakeAppRepo repo,
    Locale locale = const Locale('en'),
    CaseTrackerController? customTrackerCtrl,
  }) {
    final auth = AuthController(_MockAuthRepo())
      ..applySession(
        const UserSession(
          userId: 'user-001',
          token: 'token-001',
          authenticated: true,
          fullName: 'Sahar Rezai',
        ),
      );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith((ref) => auth),
        applicationControllerProvider.overrideWith(
          (ref) => ApplicationController(repo, 'user-001'),
        ),
        if (customTrackerCtrl != null)
          caseTrackerControllerProvider(sampleApp)
              .overrideWith((ref) => customTrackerCtrl),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: true, boldText: false),
          child: child!,
        ),
        home: const ApplicationsPage(),
      ),
    );
  }

  group('E8-02 Case Tracker & Checklist UI Tests', () {
    testWidgets(
      'renders case detail with default milestones and progress gauge',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeAppRepo([sampleApp]);

        await tester.pumpWidget(buildSubject(prefs: prefs, repo: repo));
        await tester.pumpAndSettle();

        // Open detail view
        final card = find.text('University of British Columbia Study Permit');
        expect(card, findsOneWidget);
        await tester.tap(card);
        await tester.pumpAndSettle();

        // Progress & Section Title
        expect(
          find.text('Case Milestones & Document Checklist'),
          findsOneWidget,
        );
        expect(find.text('Total: 5'), findsOneWidget);
        expect(find.text('In Progress: 1'), findsOneWidget);

        // Verify baseline milestones
        expect(
          find.text('Valid Passport & Identity Documents'),
          findsOneWidget,
        );
        expect(find.text('Language Proficiency Certificate'), findsOneWidget);
        expect(
          find.text('Educational Credential Assessment (ECA)'),
          findsOneWidget,
        );
        expect(
          find.text('Proof of Financial Sufficiency & Bank Statement'),
          findsOneWidget,
        );

        // Verify status pills
        expect(find.text('In Progress'), findsWidgets);
        expect(find.text('Not Started'), findsWidgets);
      },
    );

    testWidgets(
      'surfaces active reminders with Iran timezone context and overdue warning',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeAppRepo([sampleApp]);

        // Seed controller with an overdue item and an upcoming item
        final overdueItem = CaseChecklistItem(
          id: 'item_overdue_biometrics',
          title: 'Biometrics Center Appointment',
          status: ChecklistItemStatus.inProgress,
          dueDate: fixedClock.subtract(const Duration(days: 2)),
        );
        final upcomingItem = CaseChecklistItem(
          id: 'item_upcoming_funds',
          title: 'Bank Statement Submission',
          status: ChecklistItemStatus.notStarted,
          dueDate: fixedClock.add(const Duration(hours: 12)),
        );

        final customCtrl = CaseTrackerController(
          initialApp: sampleApp,
          userId: 'user-001',
          prefs: prefs,
          appRepository: repo,
          nowUtc: fixedClock,
        )..setCustomChecklist([overdueItem, upcomingItem]);

        await tester.pumpWidget(
          buildSubject(prefs: prefs, repo: repo, customTrackerCtrl: customCtrl),
        );
        await tester.pumpAndSettle();

        // Open detail view
        await tester.tap(
          find.text('University of British Columbia Study Permit'),
        );
        await tester.pumpAndSettle();

        // Verify Reminders Card
        expect(find.text('Pending Case Reminders'), findsOneWidget);
        expect(find.textContaining('Iranian (UTC+03:30)'), findsOneWidget);
        expect(find.text('Biometrics Center Appointment'), findsWidgets);
        expect(find.text('Overdue'), findsWidgets);
      },
    );

    testWidgets(
      'transitions checklist item status respecting transition rules and updates progress',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeAppRepo([sampleApp]);

        final singleItem = CaseChecklistItem(
          id: 'item_single_passport',
          title: 'Passport Copy Upload',
          status: ChecklistItemStatus.inProgress,
          dueDate: fixedClock.add(const Duration(days: 5)),
        );

        final customCtrl = CaseTrackerController(
          initialApp: sampleApp,
          userId: 'user-001',
          prefs: prefs,
          appRepository: repo,
          nowUtc: fixedClock,
        )..setCustomChecklist([singleItem]);

        await tester.pumpWidget(
          buildSubject(prefs: prefs, repo: repo, customTrackerCtrl: customCtrl),
        );
        await tester.pumpAndSettle();

        // Open detail view
        await tester.tap(
          find.text('University of British Columbia Study Permit'),
        );
        await tester.pumpAndSettle();

        expect(find.text('0%'), findsOneWidget);

        // Tap "Complete" action chip
        final completeAction = find.widgetWithText(ActionChip, 'Complete');
        expect(completeAction, findsOneWidget);
        await tester.tap(completeAction);
        await tester.pumpAndSettle();

        // Item is now marked Completed and progress is 100%
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('Completed'), findsWidgets);
      },
    );

    testWidgets('blocked item renders blocked badge and limits next actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeAppRepo([sampleApp]);

      final blockedItem = CaseChecklistItem(
        id: 'item_police_cert',
        title: 'Police Clearance Certificate',
        description: 'Waiting on government fingerprint processing delay.',
        status: ChecklistItemStatus.blocked,
        dueDate: fixedClock.add(const Duration(days: 10)),
      );

      final customCtrl = CaseTrackerController(
        initialApp: sampleApp,
        userId: 'user-001',
        prefs: prefs,
        appRepository: repo,
        nowUtc: fixedClock,
      )..setCustomChecklist([blockedItem]);

      await tester.pumpWidget(
        buildSubject(prefs: prefs, repo: repo, customTrackerCtrl: customCtrl),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('University of British Columbia Study Permit'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blocked'), findsWidgets);
      expect(find.text('Blocked: 1'), findsOneWidget);

      // Allowed transitions from blocked: Start / Resume, Reset, Skip
      expect(find.widgetWithText(ActionChip, 'Start / Resume'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Reset'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Skip'), findsOneWidget);
      // 'Complete' must NOT be available directly from Blocked per ChecklistTransitionRules
      expect(find.widgetWithText(ActionChip, 'Complete'), findsNothing);
    });

    testWidgets(
      'empty checklist displays empty state and generates milestones',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeAppRepo([sampleApp]);

        final customCtrl = CaseTrackerController(
          initialApp: sampleApp,
          userId: 'user-001',
          prefs: prefs,
          appRepository: repo,
          nowUtc: fixedClock,
        )..clearChecklist();

        await tester.pumpWidget(
          buildSubject(prefs: prefs, repo: repo, customTrackerCtrl: customCtrl),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('University of British Columbia Study Permit'),
        );
        await tester.pumpAndSettle();

        // Empty State
        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('No checklist items yet'), findsOneWidget);

        // Tap action to create default milestones
        final createBtn = find.text('Create Default Milestones');
        expect(createBtn, findsOneWidget);
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        // Milestones populated
        expect(
          find.text('Valid Passport & Identity Documents'),
          findsOneWidget,
        );
        expect(find.text('Total: 5'), findsOneWidget);
      },
    );

    testWidgets(
      'enforces application status transition rules and rejects invalid transitions',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeAppRepo([sampleApp]); // status: submitted

        await tester.pumpWidget(buildSubject(prefs: prefs, repo: repo));
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('University of British Columbia Study Permit'),
        );
        await tester.pumpAndSettle();

        // Attempt invalid transition: 'submitted' -> 'draft' is disallowed
        final draftFilterChip = find.widgetWithText(FilterChip, 'Draft');
        expect(draftFilterChip, findsOneWidget);
        await tester.tap(draftFilterChip);
        await tester.pumpAndSettle();

        // Snack bar warning shown and status remains submitted
        expect(
          find.textContaining('Cannot transition application from'),
          findsOneWidget,
        );
        expect(repo.apps.first.status, ApplicationStatus.submitted);
      },
    );

    testWidgets(
      'renders cleanly in Persian RTL across multiple viewports without overflows',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeAppRepo([sampleApp]);

        for (final width in [390.0, 768.0, 1200.0]) {
          tester.view.physicalSize = Size(width, 2600);
          tester.view.devicePixelRatio = 1;

          await tester.pumpWidget(
            buildSubject(prefs: prefs, repo: repo, locale: const Locale('fa')),
          );
          await tester.pumpAndSettle();

          // Tap application to open detail view in Persian
          await tester.tap(
            find.text('University of British Columbia Study Permit'),
          );
          await tester.pumpAndSettle();

          expect(find.text('چک‌لیست مراحل و مدارک پرونده'), findsOneWidget);
          expect(find.text('کل مراحل: 5'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Tap back button
          final backBtn = find.byTooltip('بازگشت به درخواست‌ها');
          expect(backBtn, findsOneWidget);
          await tester.tap(backBtn);
          await tester.pumpAndSettle();
        }
        tester.view.reset();
      },
    );

    testWidgets(
      'isolates case checklist storage per user and prevents cross-user leakage on account switch',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeAppRepo([sampleApp]);

        // User A loads the case and adds a custom item
        final userACtrl = CaseTrackerController(
          initialApp: sampleApp,
          userId: 'user-A',
          prefs: prefs,
          appRepository: repo,
        );
        await userACtrl.addChecklistItem(title: 'User A Confidential Step');

        expect(
          userACtrl.state.checklist.items.any(
            (i) => i.title == 'User A Confidential Step',
          ),
          isTrue,
        );

        // User B opens the same case
        final userBCtrl = CaseTrackerController(
          initialApp: sampleApp,
          userId: 'user-B',
          prefs: prefs,
          appRepository: repo,
        );

        // User B must NOT see User A's custom milestone
        expect(
          userBCtrl.state.checklist.items.any(
            (i) => i.title == 'User A Confidential Step',
          ),
          isFalse,
        );
      },
    );
  });
}
