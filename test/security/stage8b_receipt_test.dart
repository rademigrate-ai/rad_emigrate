import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/booking/data/booking_repository.dart';
import 'package:rad_emigrate/features/booking/domain/entities/service_booking.dart';
import 'package:rad_emigrate/features/interviews/data/appointment_repository.dart';

import '../support/mock_supabase_service.dart';
import '../support/rad_contract_fixtures.dart';

const offering = ServiceOffering(
  id: fixtureId,
  slug: 'synthetic',
  title: 'Synthetic',
  category: ServiceCategory.interviewPreparation,
  fulfillment: BookingFulfillment.staffScheduled,
);
const request = BookingRequest(serviceId: fixtureId, message: 'Synthetic');
Map<String, dynamic> row() => {
  'id': fixtureId,
  'user_id': testOwner,
  'notes': '',
  'service_id': fixtureId,
  'title': 'Synthetic',
  'kind': 'radSession',
  'status': 'confirmed',
  'created_at': '2026-10-21T00:00:00+00:00',
  'start_utc': '2027-01-01T00:00:00Z',
  'end_utc': null,
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final invalid in [
    <String, dynamic>{},
    {'id': 'placeholder'},
    {'created_at': null},
    {'created_at': '2026-02-30T00:00:00Z'},
    {'status': 'invented'},
  ]) {
    test('booking and interview reject malformed receipt $invalid', () async {
      final service = await mockSupabaseService(
        (r) async => rpcJson([
          {
            ...row(),
            if (r.url.path.endsWith('/submit_rad_appointment'))
              'status': 'requested',
            ...invalid,
          },
        ]),
      );
      final booking = SupabaseBookingRepository(service);
      final appointment = SupabaseAppointmentRepository(service);
      if (invalid.isNotEmpty) {
        await expectLater(
          booking.submitBooking(
            service: offering,
            request: request,
            locale: 'en',
          ),
          throwsA(isA<BookingException>()),
        );
        await expectLater(
          appointment.submitRadSession(
            title: 'Synthetic',
            startUtc: DateTime.utc(2027),
            endUtc: null,
            ianaZoneId: null,
            notes: '',
          ),
          throwsA(isA<AppointmentException>()),
        );
      } else {
        final b = await booking.submitBooking(
          service: offering,
          request: request,
          locale: 'en',
        );
        expect(b.id, fixtureId);
        expect(b.createdAt, DateTime.utc(2026, 10, 21));
        final a = await appointment.submitRadSession(
          title: 'Synthetic',
          startUtc: DateTime.utc(2027),
          endUtc: null,
          ianaZoneId: null,
          notes: '',
        );
        expect(a.id, fixtureId);
        expect(a.startUtc, DateTime.utc(2027));
      }
    });
  }
  for (final patch in [
    {'service_id': 'wrong-service'},
    {'start_utc': '2028-01-01T00:00:00Z'},
    {'kind': 'externalGovernment'},
  ]) {
    test(
      'receipt binds to the requested service/internal appointment $patch',
      () async {
        final service = await mockSupabaseService(
          (r) async => rpcJson([
            {
              ...row(),
              if (r.url.path.endsWith('/submit_rad_appointment'))
                'status': 'requested',
              ...patch,
            },
          ]),
        );
        if (patch.containsKey('service_id')) {
          await expectLater(
            SupabaseBookingRepository(
              service,
            ).submitBooking(service: offering, request: request, locale: 'en'),
            throwsA(isA<BookingException>()),
          );
        } else {
          await expectLater(
            SupabaseAppointmentRepository(service).submitRadSession(
              title: 'Synthetic',
              startUtc: DateTime.utc(2027),
              endUtc: null,
              ianaZoneId: null,
              notes: '',
            ),
            throwsA(isA<AppointmentException>()),
          );
        }
      },
    );
  }
}
