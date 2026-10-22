import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/auth/presentation/providers/auth_controller.dart';
import 'package:rad_emigrate/features/booking/data/booking_repository.dart';
import 'package:rad_emigrate/features/booking/domain/entities/service_booking.dart';
import 'package:rad_emigrate/features/booking/presentation/pages/booking_service_page.dart';
import 'package:rad_emigrate/features/booking/presentation/providers/booking_controller.dart';
import 'package:rad_emigrate/features/interviews/data/appointment_repository.dart';
import 'package:rad_emigrate/features/interviews/domain/entities/interview_appointment.dart';
import 'package:rad_emigrate/features/interviews/presentation/pages/interviews_page.dart';
import 'package:rad_emigrate/features/interviews/presentation/providers/appointment_controller.dart';

import 'private_view_assurance_test.dart' as harness;

const offering = ServiceOffering(
  id: 'synthetic',
  slug: 'synthetic',
  title: 'Synthetic test service',
  category: ServiceCategory.consultation,
  fulfillment: BookingFulfillment.humanConsultation,
);

class _Bookings implements BookingRepository {
  Completer<BookingRecord>? pending;
  int calls = 0;
  @override
  Future<ServiceCatalogResult> listServices({required String locale}) async =>
      const ServiceCatalogResult(
        services: [offering],
        capability: BookingCapability.available,
      );
  @override
  Future<List<BookingRecord>> listMyBookings() async => [];
  @override
  Future<BookingRecord> submitBooking({
    required ServiceOffering service,
    required BookingRequest request,
    required String locale,
  }) {
    calls++;
    return pending?.future ?? Future.value(receipt());
  }
}

BookingRecord receipt() => BookingRecord(
  id: 'synthetic-receipt',
  serviceId: offering.id,
  serviceTitle: offering.title,
  message: 'PRIVATE_A_RECEIPT',
  status: BookingStatus.submitted,
  createdAt: DateTime.utc(2026),
);
InterviewAppointment appointment() => InterviewAppointment(
  id: 'synthetic-appointment',
  kind: AppointmentKind.radSession,
  title: 'PRIVATE_A_APPOINTMENT',
  notes: 'PRIVATE_A_NOTES',
  startUtc: DateTime.utc(2027),
  status: AppointmentStatus.requested,
  createdAt: DateTime.utc(2026),
);

class _Appointments implements AppointmentRepository {
  Completer<InterviewAppointment>? pending;
  Completer<void>? mutation;
  int calls = 0;
  @override
  Future<AppointmentListResult> listMyAppointments() async =>
      const AppointmentListResult(
        appointments: [],
        capability: AppointmentCapability.available,
      );
  @override
  Future<InterviewAppointment> submitRadSession({
    required String title,
    required DateTime startUtc,
    required DateTime? endUtc,
    required String? ianaZoneId,
    required String notes,
  }) {
    calls++;
    return pending?.future ?? Future.value(appointment());
  }

  @override
  Future<void> reschedule({
    required String appointmentId,
    required DateTime startUtc,
    required DateTime? endUtc,
    required String? ianaZoneId,
    required String notes,
  }) {
    calls++;
    return mutation?.future ?? Future.value();
  }

  @override
  Future<void> cancel({required String appointmentId, required String reason}) {
    calls++;
    return mutation?.future ?? Future.value();
  }
}

Future<BookingRecord?> book(BookingSubmitController c) => c.submit(
  service: offering,
  request: const BookingRequest(
    serviceId: 'synthetic',
    message: 'PRIVATE_A_INPUT',
  ),
  locale: 'en',
);
Future<InterviewAppointment?> schedule(AppointmentController c) => c.submit(
  title: 'PRIVATE_A_INPUT',
  startUtc: DateTime.utc(2027),
  endUtc: null,
  ianaZoneId: null,
  notes: 'PRIVATE_A_NOTES',
);
void main() {
  for (final resetPending in [false, true]) {
    test(
      'booking rejects concurrent submit, reset=$resetPending, recovers after failure',
      () async {
        final repo = _Bookings()..pending = Completer<BookingRecord>();
        final controller = BookingSubmitController(repo);
        addTearDown(controller.dispose);
        final first = book(controller);
        if (resetPending) controller.reset();
        final second = book(controller);
        final firstCheck = expectLater(first, completion(isNull));
        final secondCheck = expectLater(second, completion(isNull));
        final count = repo.calls;
        repo.pending!.completeError(
          const BookingException('synthetic failure'),
        );
        await Future.wait([firstCheck, secondCheck]);
        expect(count, 1);
        expect(controller.state.phase, BookingSubmitPhase.failure);
        repo.pending = null;
        expect(await book(controller), isNotNull);
        expect(repo.calls, 2);
      },
    );
    test(
      'interview mutations exclude each other, reset=$resetPending, recover after failure',
      () async {
        final repo = _Appointments()
          ..pending = Completer<InterviewAppointment>();
        final controller = AppointmentController(repo);
        addTearDown(controller.dispose);
        final first = schedule(controller);
        if (resetPending) controller.reset();
        final second = schedule(controller);
        final cancel = controller.cancel(
          appointmentId: 'synthetic',
          reason: 'synthetic',
        );
        final reschedule = controller.reschedule(
          appointmentId: 'synthetic',
          startUtc: DateTime.utc(2027),
          endUtc: null,
          ianaZoneId: null,
          notes: 'synthetic',
        );
        final firstCheck = expectLater(first, completion(isNull));
        final secondCheck = expectLater(second, completion(isNull));
        final count = repo.calls;
        repo.pending!.completeError(
          const AppointmentException('synthetic failure'),
        );
        await Future.wait([firstCheck, secondCheck]);
        expect(await cancel, false);
        expect(await reschedule, false);
        expect(count, 1);
        repo.pending = null;
        expect(await schedule(controller), isNotNull);
        expect(repo.calls, 2);
      },
    );
  }

  test('booking receipts clear on account switch; late and disposed requests return no private result', () async {
    final repo = _Bookings();
    final c = ProviderContainer(
      overrides: [
        authenticatedUserIdProvider.overrideWith(
          (ref) => ref.watch(harness.identityProvider),
        ),
        bookingRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(bookingSubmitControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final old = c.read(bookingSubmitControllerProvider.notifier);
    expect((await book(old))?.message, 'PRIVATE_A_RECEIPT');
    repo.pending = Completer();
    final late = book(old);
    c.read(harness.identityProvider.notifier).state = harness.b;
    expect(c.read(bookingSubmitControllerProvider).record, isNull);
    repo.pending!.complete(receipt());
    expect(await late, isNull);
    expect(await book(old), isNull);
    c.read(harness.identityProvider.notifier).state = null;
    final calls = repo.calls;
    expect(
      await book(c.read(bookingSubmitControllerProvider.notifier)),
      isNull,
    );
    expect(repo.calls, calls);
  });
  test('appointment receipts and late submit/reschedule/cancel do not cross identities', () async {
    final repo = _Appointments();
    final c = ProviderContainer(
      overrides: [
        authenticatedUserIdProvider.overrideWith(
          (ref) => ref.watch(harness.identityProvider),
        ),
        appointmentRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(appointmentControllerProvider, (_, _) {});
    addTearDown(sub.close);
    expect(
      (await schedule(c.read(appointmentControllerProvider.notifier)))?.notes,
      'PRIVATE_A_NOTES',
    );
    repo.pending = Completer();
    final late = schedule(c.read(appointmentControllerProvider.notifier));
    c.read(harness.identityProvider.notifier).state = harness.b;
    expect(c.read(appointmentControllerProvider).appointment, isNull);
    repo.pending!.complete(appointment());
    expect(await late, isNull);
    for (final cancel in [false, true]) {
      repo.mutation = Completer();
      final controller = c.read(appointmentControllerProvider.notifier);
      final pending = cancel
          ? controller.cancel(appointmentId: 'synthetic', reason: 'private')
          : controller.reschedule(
              appointmentId: 'synthetic',
              startUtc: DateTime.utc(2027),
              endUtc: null,
              ianaZoneId: null,
              notes: 'private',
            );
      c.read(harness.identityProvider.notifier).state = cancel
          ? null
          : harness.a;
      c.read(appointmentControllerProvider);
      repo.mutation!.complete();
      expect(await pending, isFalse);
    }
    final calls = repo.calls;
    expect(
      await schedule(c.read(appointmentControllerProvider.notifier)),
      isNull,
    );
    expect(repo.calls, calls);
  });
  for (final booking in [true, false]) {
    testWidgets(
      '${booking ? 'booking' : 'interview'} form drops private draft on logout and B switch',
      (tester) async {
        final c = ProviderContainer(
          overrides: [
            authenticatedUserIdProvider.overrideWith(
              (ref) => ref.watch(harness.identityProvider),
            ),
            authControllerProvider.overrideWith((ref) => harness.mirror()),
            bookingRepositoryProvider.overrideWithValue(_Bookings()),
            appointmentRepositoryProvider.overrideWithValue(_Appointments()),
          ],
        );
        try {
          await tester.pumpWidget(
            harness.root(
              c,
              booking
                  ? const BookingServicePage(serviceId: 'synthetic')
                  : const InterviewsPage(),
            ),
          );
          await tester.pumpAndSettle();
          final inputs = find.byType(TextFormField);
          expect(inputs, findsWidgets);
          await tester.enterText(inputs.first, 'PRIVATE_A_UNSAVED');
          c.read(harness.identityProvider.notifier).state = null;
          await tester.pumpAndSettle();
          expect(find.text('PRIVATE_A_UNSAVED'), findsNothing);
          c.read(harness.identityProvider.notifier).state = harness.b;
          await tester.pumpAndSettle();
          expect(find.text('PRIVATE_A_UNSAVED'), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          c.dispose();
        }
      },
    );
  }
}
