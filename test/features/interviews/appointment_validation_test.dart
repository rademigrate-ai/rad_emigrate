import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/global_time/domain/timezone_engine.dart';
import 'package:rad_emigrate/features/interviews/domain/appointment_time.dart';
import 'package:rad_emigrate/features/interviews/domain/appointment_validation.dart';
import 'package:rad_emigrate/features/interviews/domain/entities/interview_appointment.dart';

void main() {
  final nowUtc = DateTime.utc(2026, 10, 20, 12);

  setUpAll(() async {
    await TimezoneEngine.ensureInitialized();
  });

  group('AppointmentValidation.validateTitle', () {
    test('rejects empty', () {
      final r = AppointmentValidation.validateTitle('  ');
      expect(r.isValid, isFalse);
      expect(r.errorKey, 'appointmentTitleRequired');
      expect(r.field, 'title');
    });

    test('rejects too short and too long', () {
      expect(
        AppointmentValidation.validateTitle('ab').errorKey,
        'appointmentTitleTooShort',
      );
      expect(
        AppointmentValidation.validateTitle('a' * 121).errorKey,
        'appointmentTitleTooLong',
      );
    });

    test('accepts a normal title', () {
      expect(
        AppointmentValidation.validateTitle('Study interview prep').isValid,
        isTrue,
      );
    });
  });

  group('AppointmentValidation.validateStart', () {
    test('missing start rejected', () {
      final r = AppointmentValidation.validateStart(
        startUtc: null,
        nowUtc: nowUtc,
      );
      expect(r.errorKey, 'appointmentStartRequired');
      expect(r.field, 'start');
    });

    test('past start rejected', () {
      final r = AppointmentValidation.validateStart(
        startUtc: nowUtc.subtract(const Duration(minutes: 5)),
        nowUtc: nowUtc,
      );
      expect(r.errorKey, 'appointmentStartPast');
    });

    test('future start accepted', () {
      final r = AppointmentValidation.validateStart(
        startUtc: nowUtc.add(const Duration(days: 1)),
        nowUtc: nowUtc,
      );
      expect(r.isValid, isTrue);
    });
  });

  group('AppointmentValidation.validateEnd', () {
    final start = nowUtc.add(const Duration(days: 1));

    test('optional when null', () {
      expect(
        AppointmentValidation.validateEnd(
          endUtc: null,
          startUtc: start,
        ).isValid,
        isTrue,
      );
    });

    test('end before start rejected', () {
      final r = AppointmentValidation.validateEnd(
        endUtc: start.subtract(const Duration(minutes: 10)),
        startUtc: start,
      );
      expect(r.errorKey, 'appointmentEndBeforeStart');
    });

    test('under 15 minutes rejected', () {
      final r = AppointmentValidation.validateEnd(
        endUtc: start.add(const Duration(minutes: 10)),
        startUtc: start,
      );
      expect(r.errorKey, 'appointmentTooShort');
    });

    test('over 4 hours rejected', () {
      final r = AppointmentValidation.validateEnd(
        endUtc: start.add(const Duration(hours: 5)),
        startUtc: start,
      );
      expect(r.errorKey, 'appointmentTooLong');
    });
  });

  group('AppointmentValidation.validate (full request)', () {
    test('external government kind is never bookable', () {
      final r = AppointmentValidation.validate(
        kind: AppointmentKind.externalGovernment,
        title: 'Embassy visa appointment',
        startUtc: nowUtc.add(const Duration(days: 2)),
        nowUtc: nowUtc,
      );
      expect(r.isValid, isFalse);
      expect(r.errorKey, 'appointmentExternalNotBookable');
      expect(r.field, 'kind');
    });

    test('RAD session with future start passes', () {
      final r = AppointmentValidation.validate(
        kind: AppointmentKind.radSession,
        title: 'Study interview prep',
        startUtc: nowUtc.add(const Duration(days: 2)),
        endUtc: nowUtc.add(const Duration(days: 2, hours: 1)),
        nowUtc: nowUtc,
      );
      expect(r.isValid, isTrue);
    });

    test('title validated before start', () {
      final r = AppointmentValidation.validate(
        kind: AppointmentKind.radSession,
        title: 'ab',
        nowUtc: nowUtc,
      );
      expect(r.errorKey, 'appointmentTitleTooShort');
    });
  });

  group('CivilTimeInZone (timezone-safe conversion)', () {
    test('converts Tehran civil time to the correct UTC instant', () {
      final civil = CivilTimeInZone(
        year: 2026,
        month: 10,
        day: 25,
        hour: 15,
        minute: 0,
        ianaZoneId: 'Asia/Tehran',
      );
      final utc = civil.toUtcOrNull();
      expect(utc, isNotNull);
      // Tehran is UTC+3:30 (or +4:30 under historical DST rules).
      final diffHours = utc!.difference(DateTime.utc(2026, 10, 25, 15)).inHours;
      expect(diffHours == -3 || diffHours == -4, isTrue);
      expect(civil.isDstGap, isFalse);
      expect(civil.isDstFold, isFalse);
    });

    test('DST gap time returns null (never a wrong guess)', () {
      // Berlin spring-forward 2026-03-29 02:00 → 03:00 (CEST).
      final civil = CivilTimeInZone(
        year: 2026,
        month: 3,
        day: 29,
        hour: 2,
        minute: 30,
        ianaZoneId: 'Europe/Berlin',
      );
      expect(civil.toUtcOrNull(), isNull);
      expect(civil.isDstGap, isTrue);
    });

    test('DST fold time is flagged as ambiguous', () {
      // Berlin fall-back 2026-10-25 02:00 → 01:00 (CET), 02:30 repeats.
      final civil = CivilTimeInZone(
        year: 2026,
        month: 10,
        day: 25,
        hour: 2,
        minute: 30,
        ianaZoneId: 'Europe/Berlin',
      );
      expect(civil.isDstFold, isTrue);
      final utc = civil.toUtcOrNull();
      expect(utc, isNotNull); // First occurrence used, ambiguity surfaced.
    });

    test('AppointmentTimeDisplay.inZone converts an instant into the zone', () {
      final utc = DateTime.utc(2026, 10, 25, 12, 0);
      final inTehran = AppointmentTimeDisplay.inZone(utc, 'Asia/Tehran');
      expect(inTehran, isNotNull);
      expect(inTehran!.hour, 15); // +3:30 → 15:30, floored to hour 15:30.
      expect(inTehran.minute, 30);
    });

    test('offsetLabel reports zone offset', () {
      final label = AppointmentTimeDisplay.offsetLabel(
        'Asia/Tehran',
        at: DateTime.utc(2026, 10, 25),
      );
      expect(label, startsWith('GMT+'));
    });
  });

  group('appointment JSON round-trip', () {
    test('preserves kind, status, and zone', () {
      final appointment = InterviewAppointment(
        id: 'a1',
        kind: AppointmentKind.radSession,
        title: 'Study interview prep',
        startUtc: DateTime.utc(2026, 11, 1, 14),
        status: AppointmentStatus.requested,
        createdAt: DateTime.utc(2026, 10, 20),
        ianaZoneId: 'Europe/Berlin',
        notes: 'prepare documents',
      );
      final restored = InterviewAppointment.fromJson(appointment.toJson());
      expect(restored.kind, AppointmentKind.radSession);
      expect(restored.status, AppointmentStatus.requested);
      expect(restored.ianaZoneId, 'Europe/Berlin');
      expect(restored.startUtc, DateTime.utc(2026, 11, 1, 14));
      expect(restored.backendManaged, isTrue);
    });

    test('unknown status maps to unknown, never confirmed', () {
      expect(AppointmentStatusX.fromString('maybe'), AppointmentStatus.unknown);
      expect(AppointmentStatusX.fromString(null), AppointmentStatus.unknown);
      expect(AppointmentStatus.unknown.isConfirmed, isFalse);
      expect(AppointmentStatus.requested.isConfirmed, isFalse);
      expect(AppointmentStatus.confirmed.isConfirmed, isTrue);
    });

    test('external kind parses back', () {
      final appointment = InterviewAppointment(
        id: 'a2',
        kind: AppointmentKind.externalGovernment,
        title: 'Consulate appointment (personal)',
        startUtc: DateTime.utc(2026, 11, 5, 9),
        status: AppointmentStatus.unknown,
        createdAt: DateTime.utc(2026, 10, 20),
        backendManaged: false,
      );
      final restored = InterviewAppointment.fromJson(appointment.toJson());
      expect(restored.kind, AppointmentKind.externalGovernment);
      expect(restored.backendManaged, isFalse);
    });
  });
}
