import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/interview_scheduling/data/interview_repository.dart';
import 'package:rad_emigrate/features/interview_scheduling/domain/entities/interview_slot.dart';
import 'package:rad_emigrate/features/interview_scheduling/presentation/pages/interview_scheduling_page.dart';
import 'package:rad_emigrate/features/interview_scheduling/presentation/providers/interview_controller.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

class FakeInterviewRepository implements InterviewRepository {
  FakeInterviewRepository({this.slots, this.shouldFail = false});
  final List<InterviewSlot>? slots;
  final bool shouldFail;

  @override
  Future<List<InterviewSlot>> listAvailableSlots({
    required String locale,
  }) async {
    if (shouldFail) {
      throw const InterviewBackendUnavailableException('list_interview_slots');
    }
    return slots ??
        [
          InterviewSlot(
            id: 'slot-1',
            title: locale == 'fa'
                ? 'شبیه‌سازی مصاحبه سفارت آلمان'
                : 'German Embassy Simulation',
            startUtc: DateTime.utc(2026, 10, 25, 10, 0),
            endUtc: DateTime.utc(2026, 10, 25, 10, 45),
            mode: InterviewMode.video,
          ),
        ];
  }

  @override
  Future<InterviewBookingRecord> scheduleInterview({
    required String slotId,
    required String notes,
    required String locale,
  }) async {
    return InterviewBookingRecord(
      id: 'rec-1',
      slotId: slotId,
      scheduledStartUtc: DateTime.utc(2026, 10, 25, 10, 0),
      status: 'confirmed',
      createdAtUtc: DateTime.now().toUtc(),
    );
  }
}

void main() {
  testWidgets('InterviewSchedulingPage renders slots when available', (
    tester,
  ) async {
    final fakeRepo = FakeInterviewRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [interviewRepositoryProvider.overrideWithValue(fakeRepo)],
        child: const MaterialApp(
          locale: Locale('fa'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InterviewSchedulingPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('زمان‌بندی مصاحبه تخصصی'), findsOneWidget);
    expect(find.text('شبیه‌سازی مصاحبه سفارت آلمان'), findsOneWidget);
    expect(find.text('مصاحبه ویدیویی'), findsOneWidget);
  });

  testWidgets(
    'InterviewSchedulingPage renders explicit capability notice when backend unavailable',
    (tester) async {
      final fakeRepo = FakeInterviewRepository(shouldFail: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [interviewRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(
            locale: Locale('fa'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InterviewSchedulingPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('سامانه زمان‌بندی خودکار در حال راه‌اندازی است'),
        findsOneWidget,
      );
      expect(find.text('درخواست مشاوره تخصصی'), findsOneWidget);
    },
  );
}
