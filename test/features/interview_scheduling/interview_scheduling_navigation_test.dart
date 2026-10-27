import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rad_emigrate/features/interview_scheduling/data/interview_repository.dart';
import 'package:rad_emigrate/features/interview_scheduling/domain/entities/interview_slot.dart';
import 'package:rad_emigrate/features/interview_scheduling/presentation/pages/interview_scheduling_page.dart';
import 'package:rad_emigrate/features/interview_scheduling/presentation/providers/interview_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

/// Scheduling backend not installed: the documented fail-closed state in which
/// the page's only call to action is "Request Consultation".
class _UnavailableInterviewRepository implements InterviewRepository {
  @override
  Future<List<InterviewSlot>> listAvailableSlots({required String locale}) {
    throw const InterviewBackendUnavailableException('list_interview_slots');
  }

  @override
  Future<InterviewBookingRecord> scheduleInterview({
    required String slotId,
    required String notes,
    required String locale,
  }) {
    throw const InterviewBackendUnavailableException('schedule_interview');
  }
}

/// Mounts the page behind a real [GoRouter], the same navigation mechanism the
/// production app uses. A plain `MaterialApp(home: ...)` has a root Navigator
/// that can resolve named routes differently and therefore hides routing bugs.
Widget _app(Locale locale) {
  final router = GoRouter(
    initialLocation: '/interview-scheduling',
    routes: [
      GoRoute(
        path: '/interview-scheduling',
        builder: (_, _) => const InterviewSchedulingPage(),
      ),
      GoRoute(
        path: '/consultation',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('consultation-destination'))),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('dashboard')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      interviewRepositoryProvider.overrideWithValue(
        _UnavailableInterviewRepository(),
      ),
    ],
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets(
    'EN: Request Consultation navigates to /consultation through GoRouter',
    (tester) async {
      await tester.pumpWidget(_app(const Locale('en')));
      await tester.pumpAndSettle();

      final button = find.text('Request Consultation');
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('consultation-destination'), findsOneWidget);
    },
  );

  testWidgets(
    'FA: درخواست مشاوره تخصصی navigates to /consultation through GoRouter',
    (tester) async {
      await tester.pumpWidget(_app(const Locale('fa')));
      await tester.pumpAndSettle();

      final button = find.text('درخواست مشاوره تخصصی');
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('consultation-destination'), findsOneWidget);
    },
  );
}
