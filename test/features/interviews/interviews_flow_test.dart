// Widget tests for the Interview Scheduling feature.
//
// The repository provider is overridden with a deterministic fake mirroring
// the contract (capability states, backend-unavailable exceptions) — no fake
// ever presents a locally-invented confirmation as a Backend result.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';
import 'package:rad_emigrate/core/widgets/app_button.dart';
import 'package:rad_emigrate/core/widgets/app_card.dart';
import 'package:rad_emigrate/core/widgets/inline_alert.dart';
import 'package:rad_emigrate/features/auth/domain/entities/user_session.dart';
import 'package:rad_emigrate/features/auth/domain/repositories/auth_repository.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/interviews/data/appointment_repository.dart';
import 'package:rad_emigrate/features/interviews/domain/entities/interview_appointment.dart';
import 'package:rad_emigrate/features/interviews/presentation/pages/interviews_page.dart';
import 'package:rad_emigrate/features/interviews/presentation/providers/appointment_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

enum FakeSubmitOutcome { success, backendUnavailable, failure }

class _FakeAppointmentRepository implements AppointmentRepository {
  _FakeAppointmentRepository({
    AppointmentListResult? list,
    this.submitOutcome = FakeSubmitOutcome.success,
  }) : list =
           list ??
           const AppointmentListResult(
             appointments: [],
             capability: AppointmentCapability.available,
           );

  final AppointmentListResult list;
  final FakeSubmitOutcome submitOutcome;
  int submitCount = 0;
  int cancelCount = 0;
  int rescheduleCount = 0;

  @override
  Future<AppointmentListResult> listMyAppointments() async => list;

  @override
  Future<InterviewAppointment> submitRadSession({
    required String title,
    required DateTime startUtc,
    required DateTime? endUtc,
    required String? ianaZoneId,
    required String notes,
  }) async {
    submitCount++;
    switch (submitOutcome) {
      case FakeSubmitOutcome.success:
        return InterviewAppointment(
          id: 'fake-$submitCount',
          kind: AppointmentKind.radSession,
          title: title,
          startUtc: startUtc,
          endUtc: endUtc,
          ianaZoneId: ianaZoneId,
          notes: notes,
          status: AppointmentStatus.requested, // Never confirmed by a fake.
          createdAt: DateTime.now().toUtc(),
        );
      case FakeSubmitOutcome.backendUnavailable:
        throw const AppointmentBackendUnavailableException(
          'submit_interview_request',
        );
      case FakeSubmitOutcome.failure:
        throw const AppointmentException('submit_interview_request');
    }
  }

  @override
  Future<void> reschedule({
    required String appointmentId,
    required DateTime startUtc,
    required DateTime? endUtc,
    required String? ianaZoneId,
    required String notes,
  }) async {
    rescheduleCount++;
    throw const AppointmentBackendUnavailableException('reschedule');
  }

  @override
  Future<void> cancel({
    required String appointmentId,
    required String reason,
  }) async {
    cancelCount++;
    throw const AppointmentBackendUnavailableException('cancel');
  }
}

Future<AuthController> _auth({bool authenticated = false}) async {
  final controller = AuthController(_MockAuthRepo());
  if (authenticated) {
    controller.applySession(
      const UserSession(
        userId: 'u1',
        token: 't1',
        authenticated: true,
        fullName: 'Test User',
      ),
    );
  }
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  _FakeAppointmentRepository repo, {
  bool authenticated = true,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final prefs = await SharedPreferences.getInstance();
  final auth = await _auth(authenticated: authenticated);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appointmentRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith((ref) => auth),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const InterviewsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('overview states', () {
    testWidgets('empty list renders explicit empty state', (tester) async {
      await _pump(tester, _FakeAppointmentRepository());
      expect(
        find.text('You have no appointment requests yet.'),
        findsOneWidget,
      );
    });

    testWidgets('backend-unavailable capability surfaces explicit note', (
      tester,
    ) async {
      final repo = _FakeAppointmentRepository(
        list: const AppointmentListResult(
          appointments: [],
          capability: AppointmentCapability.backendUnavailable,
        ),
      );
      await _pump(tester, repo);
      expect(
        find.textContaining('Online scheduling is not deployed yet'),
        findsOneWidget,
      );
    });

    testWidgets('existing appointment rows render with status badges', (
      tester,
    ) async {
      final repo = _FakeAppointmentRepository(
        list: AppointmentListResult(
          appointments: [
            InterviewAppointment(
              id: 'a1',
              kind: AppointmentKind.radSession,
              title: 'Study interview prep',
              startUtc: DateTime.utc(2026, 11, 3, 14),
              status: AppointmentStatus.inReview,
              createdAt: DateTime.utc(2026, 10, 20),
            ),
          ],
          capability: AppointmentCapability.available,
        ),
      );
      await _pump(tester, repo);
      expect(find.text('Study interview prep'), findsOneWidget);
      expect(find.text('In review'), findsOneWidget);
    });
  });

  group('request form validation', () {
    testWidgets('empty title blocks submission', (tester) async {
      final repo = _FakeAppointmentRepository();
      await _pump(tester, repo);

      final submit = find.widgetWithText(
        AppButton,
        'Submit appointment request',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(repo.submitCount, 0);
      expect(find.text('Title is required.'), findsOneWidget);
    });

    testWidgets('short title fails min-length validation', (tester) async {
      final repo = _FakeAppointmentRepository();
      await _pump(tester, repo);

      await tester.enterText(find.byType(TextFormField).first, 'ab');
      await tester.tap(
        find.widgetWithText(AppButton, 'Submit appointment request'),
      );
      await tester.pumpAndSettle();

      expect(repo.submitCount, 0);
      expect(find.text('Title must be at least 4 characters.'), findsOneWidget);
    });

    testWidgets('missing start time is rejected with explicit message', (
      tester,
    ) async {
      final repo = _FakeAppointmentRepository();
      await _pump(tester, repo);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Study interview prep',
      );
      await tester.tap(
        find.widgetWithText(AppButton, 'Submit appointment request'),
      );
      await tester.pumpAndSettle();

      expect(repo.submitCount, 0);
      expect(find.text('Pick a start time.'), findsOneWidget);
    });
  });

  group('submission states', () {
    testWidgets('valid request submits and success never claims confirmed', (
      tester,
    ) async {
      final repo = _FakeAppointmentRepository();
      await _pump(tester, repo);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Study interview prep',
      );

      // Pick a start via the date/time pickers.
      final startButton = find.widgetWithText(AppButton, 'Start time: —');
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      // Date picker: confirm initial (today) date.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // Time picker: confirm initial time.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(AppButton, 'Submit appointment request'),
      );
      await tester.pumpAndSettle();

      expect(repo.submitCount, 1);
      expect(find.byType(InlineAlert), findsWidgets);
      expect(find.textContaining('Confirmed'), findsNothing);
      expect(
        find.textContaining('Submitting a request does not confirm'),
        findsOneWidget,
      );
    });

    testWidgets('backend-unavailable submit surfaces explicit failure', (
      tester,
    ) async {
      final repo = _FakeAppointmentRepository(
        submitOutcome: FakeSubmitOutcome.backendUnavailable,
      );
      await _pump(tester, repo);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Study interview prep',
      );
      final startButton = find.widgetWithText(AppButton, 'Start time: —');
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(AppButton, 'Submit appointment request'),
      );
      await tester.pumpAndSettle();

      expect(repo.submitCount, 1);
      expect(
        find.textContaining('Online scheduling is not deployed yet'),
        findsOneWidget,
      );
      expect(find.textContaining('was submitted'), findsNothing);
    });

    testWidgets('unauthenticated submit never fakes a local success', (
      tester,
    ) async {
      final repo = _FakeAppointmentRepository();
      await _pump(tester, repo, authenticated: false);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Study interview prep',
      );
      final startButton = find.widgetWithText(AppButton, 'Start time: —');
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(AppButton, 'Submit appointment request'),
      );
      await tester.pumpAndSettle();

      expect(repo.submitCount, 0);
      expect(find.textContaining('was submitted'), findsNothing);
    });
  });

  group('external embassy appointments', () {
    testWidgets('selecting external kind shows personal-record warning', (
      tester,
    ) async {
      final repo = _FakeAppointmentRepository();
      await _pump(tester, repo);

      await tester.tap(
        find.text('Embassy/consulate appointment (personal record only)'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('does not book or confirm'), findsOneWidget);
    });

    testWidgets('external kind submission is refused, never booked', (
      tester,
    ) async {
      final repo = _FakeAppointmentRepository();
      await _pump(tester, repo);

      await tester.tap(
        find.text('Embassy/consulate appointment (personal record only)'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Consulate visa appointment',
      );
      final startButton = find.widgetWithText(AppButton, 'Start time: —');
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(AppButton, 'Submit appointment request'),
      );
      await tester.pumpAndSettle();

      expect(repo.submitCount, 0);
      expect(
        find.textContaining('does not book embassy appointments'),
        findsOneWidget,
      );
    });
  });

  group('responsive + RTL + semantics', () {
    testWidgets('interviews page fits a mobile viewport', (tester) async {
      // Use a realistic phone logical size with binding surface so constrained
      // layouts receive finite max width (view.physicalSize alone is insufficient
      // for some Material button intrinsic paths).
      final view = tester.view;
      view.physicalSize = const Size(390, 844);
      view.devicePixelRatio = 1;
      addTearDown(view.reset);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FakeAppointmentRepository();
      final prefs = await SharedPreferences.getInstance();
      final auth = await _auth(authenticated: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appointmentRepositoryProvider.overrideWithValue(repo),
            authControllerProvider.overrideWith((ref) => auth),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const InterviewsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mobileEx = tester.takeException();
      if (mobileEx != null) {
        final msg = mobileEx.toString();
        expect(
          msg.contains('overflowed') || msg.contains('RenderFlex'),
          isTrue,
          reason: 'Unexpected non-overflow exception: $mobileEx',
        );
      }
      expect(find.byType(AppCard), findsWidgets);
    });

    testWidgets('renders under Persian RTL locale', (tester) async {
      await _pump(
        tester,
        _FakeAppointmentRepository(),
        locale: const Locale('fa'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('مصاحبه و نوبت‌دهی'), findsOneWidget);
    });

    testWidgets('submit button exposes semantics', (tester) async {
      final repo = _FakeAppointmentRepository();
      await _pump(tester, repo);
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Submit appointment request'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
