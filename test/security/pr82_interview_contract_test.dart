import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rad_emigrate/features/interviews/data/appointment_repository.dart';
import 'package:rad_emigrate/features/interviews/domain/entities/interview_appointment.dart';

import '../support/mock_supabase_service.dart';
import '../support/rad_contract_fixtures.dart';

Map<String, dynamic> receipt({String status = 'requested'}) => {
  'id': fixtureId,
  'user_id': testOwner,
  'kind': 'radSession',
  'title': 'SYNTHETIC request only',
  'notes': 'SYNTHETIC notes',
  'cancellation_reason': status == 'cancelled'
      ? 'SYNTHETIC cancellation'
      : null,
  'status': status,
  'start_utc': '2027-01-01T00:00:00+00:00',
  'end_utc': null,
  'time_zone': null,
  'created_at': '2026-10-25T00:00:00+00:00',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'PR82 appointment list uses explicit request adapter vocabulary',
    () async {
      final service = await mockSupabaseService((r) async {
        expect(r.url.path, endsWith('/list_rad_appointments'));
        return rpcJson([receipt()]);
      });
      final result = await SupabaseAppointmentRepository(service)
          .listMyAppointments();
      expect(result.capability, AppointmentCapability.available);
      expect(result.appointments.single.status, AppointmentStatus.requested);
      expect(result.appointments.single.status.isConfirmed, isFalse);
    },
  );
  test('PR82 submit retains UUID key after uncertain retry', () async {
    final keys = <String>[];
    var calls = 0;
    final service = await mockSupabaseService((r) async {
      expect(r.url.path, endsWith('/submit_rad_appointment'));
      final body = jsonDecode(r.body) as Map;
      expect(body['p_title'], 'SYNTHETIC request only');
      keys.add(body['p_idempotency_key'] as String);
      expect(keys.last, matches(RegExp(r'^[0-9a-f-]{36}$')));
      if (calls++ == 0) return rpcJson({'code': 'XX000'}, 503);
      return rpcJson([receipt()]);
    });
    final repo = SupabaseAppointmentRepository(service);
    Future<InterviewAppointment> submit() => repo.submitRadSession(
      title: 'SYNTHETIC request only',
      startUtc: DateTime.utc(2027),
      endUtc: null,
      ianaZoneId: null,
      notes: 'SYNTHETIC notes',
    );
    await expectLater(submit(), throwsA(isA<AppointmentException>()));
    expect((await submit()).status, AppointmentStatus.requested);
    expect(keys, hasLength(2));
    expect(keys[0], keys[1]);
  });
  test(
    'PR82 reschedule and cancel require matching persisted receipt',
    () async {
      final service = await mockSupabaseService((r) async {
        final body = jsonDecode(r.body) as Map;
        expect(body['p_appointment_id'], fixtureId);
        if (r.url.path.endsWith('/reschedule_rad_appointment')) {
          expect(body['p_start_utc'], '2027-01-01T00:00:00.000Z');
          return rpcJson([receipt(status: 'rescheduled')]);
        }
        expect(r.url.path, endsWith('/cancel_rad_appointment'));
        expect(body['p_reason'], 'SYNTHETIC cancellation');
        return rpcJson([receipt(status: 'cancelled')]);
      });
      final repo = SupabaseAppointmentRepository(service);
      await repo.reschedule(
        appointmentId: fixtureId,
        startUtc: DateTime.utc(2027),
        endUtc: null,
        ianaZoneId: null,
        notes: 'SYNTHETIC notes',
      );
      await repo.cancel(
        appointmentId: fixtureId,
        reason: 'SYNTHETIC cancellation',
      );
    },
  );
  test('PR82 empty mutation receipt is never acknowledged', () async {
    final service = await mockSupabaseService((_) async => rpcJson([]));
    await expectLater(
      SupabaseAppointmentRepository(service)
          .cancel(appointmentId: fixtureId, reason: 'SYNTHETIC cancellation'),
      throwsA(isA<AppointmentException>()),
    );
  });

  for (final invalid in [
    {...receipt(), 'user_id': 'b1111111-1111-4111-8111-111111111111'},
    {...receipt(), 'status': 'confirmed'},
    {...receipt(), 'kind': 'externalGovernment'},
    {...receipt(), 'start_utc': '2030-01-01T00:00:00Z'},
    {...receipt(), 'time_zone': 'Europe/London'},
    {...receipt(), 'id': 'not-a-uuid'},
    {...receipt(), 'created_at': null},
  ]) {
    test(
      'PR82 submit rejects unrelated or malformed receipt $invalid',
      () async {
        final service = await mockSupabaseService(
          (_) async => rpcJson([invalid]),
        );
        await expectLater(
          SupabaseAppointmentRepository(service).submitRadSession(
            title: 'SYNTHETIC request only',
            startUtc: DateTime.utc(2027),
            endUtc: null,
            ianaZoneId: null,
            notes: 'SYNTHETIC notes',
          ),
          throwsA(isA<AppointmentException>()),
        );
      },
    );
  }

  test(
    'PR82 concurrent identical client requests share the UUID retry key',
    () async {
      final keys = <String>[];
      final gate = Completer<void>();
      final service = await mockSupabaseService((r) async {
        keys.add((jsonDecode(r.body) as Map)['p_idempotency_key'] as String);
        if (keys.length == 2) gate.complete();
        await gate.future;
        return rpcJson([receipt()]);
      });
      final repo = SupabaseAppointmentRepository(service);
      Future<InterviewAppointment> submit() => repo.submitRadSession(
        title: 'SYNTHETIC request only',
        startUtc: DateTime.utc(2027),
        endUtc: null,
        ianaZoneId: null,
        notes: 'SYNTHETIC notes',
      );
      final responses = await Future.wait([submit(), submit()]);
      expect(keys.toSet(), hasLength(1));
      expect(responses.map((r) => r.id).toSet(), {fixtureId});
    },
  );

  test('PR82 rejects response after the authenticated session ends', () async {
    final received = Completer<void>();
    final release = Completer<void>();
    final service = await mockSupabaseService((request) async {
      if (request.url.path.endsWith('/logout')) return rpcJson({});
      received.complete();
      await release.future;
      return rpcJson([receipt()]);
    });
    final pending = SupabaseAppointmentRepository(service).submitRadSession(
      title: 'SYNTHETIC request only',
      startUtc: DateTime.utc(2027),
      endUtc: null,
      ianaZoneId: null,
      notes: 'SYNTHETIC notes',
    );
    final assertion = expectLater(
      pending,
      throwsA(isA<AppointmentException>()),
    );
    await received.future;
    await service.client.auth.signOut(scope: SignOutScope.local);
    release.complete();
    await assertion;
  });

  test('PR82 unrelated list receipt never enters the result', () async {
    final service = await mockSupabaseService(
      (_) async => rpcJson([
        {...receipt(), 'user_id': 'b1111111-1111-4111-8111-111111111111'},
      ]),
    );
    final result = await SupabaseAppointmentRepository(service)
        .listMyAppointments();
    expect(result.appointments, isEmpty);
    expect(result.capability, AppointmentCapability.unknown);
  });
}
