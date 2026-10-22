import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/booking/domain/booking_validation.dart';
import 'package:rad_emigrate/features/booking/domain/entities/service_booking.dart';

void main() {
  final nowUtc = DateTime.utc(2026, 10, 20, 12);

  final consultation = ServiceOffering(
    id: 'built-in-consultation',
    slug: 'consultation',
    title: 'RAD expert consultation',
    category: ServiceCategory.consultation,
    fulfillment: BookingFulfillment.humanConsultation,
  );

  final scheduled = ServiceOffering(
    id: 'svc-scheduled',
    slug: 'document-review',
    title: 'Document review',
    category: ServiceCategory.documentReview,
    fulfillment: BookingFulfillment.staffScheduled,
  );

  group('BookingValidation.validateMessage', () {
    test('rejects empty', () {
      final r = BookingValidation.validateMessage('   ');
      expect(r.isValid, isFalse);
      expect(r.errorKey, 'bookingMessageRequired');
      expect(r.field, 'message');
    });

    test('rejects shorter than 10 chars', () {
      final r = BookingValidation.validateMessage('short');
      expect(r.errorKey, 'bookingMessageTooShort');
    });

    test('rejects longer than 1000 chars', () {
      final r = BookingValidation.validateMessage('a' * 1001);
      expect(r.errorKey, 'bookingMessageTooLong');
    });

    test('accepts a normal message', () {
      final r = BookingValidation.validateMessage(
        'I need help with my Germany Opportunity Card application.',
      );
      expect(r.isValid, isTrue);
    });
  });

  group('BookingValidation.validatePreferredSlot', () {
    test('null slot is valid (optional)', () {
      final r = BookingValidation.validatePreferredSlot(
        startUtc: null,
        endUtc: null,
        nowUtc: nowUtc,
      );
      expect(r.isValid, isTrue);
    });

    test('half-picked slot is invalid', () {
      final r = BookingValidation.validatePreferredSlot(
        startUtc: nowUtc.add(const Duration(days: 1)),
        endUtc: null,
        nowUtc: nowUtc,
      );
      expect(r.errorKey, 'bookingSlotIncomplete');
    });

    test('end before start is invalid', () {
      final r = BookingValidation.validatePreferredSlot(
        startUtc: nowUtc.add(const Duration(days: 1, hours: 2)),
        endUtc: nowUtc.add(const Duration(days: 1)),
        nowUtc: nowUtc,
      );
      expect(r.errorKey, 'bookingSlotOrder');
    });

    test('slot under 15 minutes is invalid', () {
      final r = BookingValidation.validatePreferredSlot(
        startUtc: nowUtc.add(const Duration(days: 1)),
        endUtc: nowUtc.add(const Duration(days: 1, minutes: 10)),
        nowUtc: nowUtc,
      );
      expect(r.errorKey, 'bookingSlotTooShort');
    });

    test('slot over 24 hours is invalid', () {
      final r = BookingValidation.validatePreferredSlot(
        startUtc: nowUtc.add(const Duration(days: 1)),
        endUtc: nowUtc.add(const Duration(days: 2, minutes: 1)),
        nowUtc: nowUtc,
      );
      expect(r.errorKey, 'bookingSlotTooLong');
    });

    test('past slot is invalid', () {
      final r = BookingValidation.validatePreferredSlot(
        startUtc: nowUtc.subtract(const Duration(hours: 1)),
        endUtc: nowUtc.add(const Duration(hours: 1)),
        nowUtc: nowUtc,
      );
      expect(r.errorKey, 'bookingSlotPast');
    });

    test('valid future slot passes', () {
      final r = BookingValidation.validatePreferredSlot(
        startUtc: nowUtc.add(const Duration(days: 1)),
        endUtc: nowUtc.add(const Duration(days: 1, hours: 1)),
        nowUtc: nowUtc,
      );
      expect(r.isValid, isTrue);
    });
  });

  group('BookingValidation.validate (full request)', () {
    test('consultation does not require a slot', () {
      final r = BookingValidation.validate(
        service: consultation,
        message: 'Please review my Germany application plan.',
        nowUtc: nowUtc,
      );
      expect(r.isValid, isTrue);
    });

    test('staff-scheduled service requires a preferred slot', () {
      final r = BookingValidation.validate(
        service: scheduled,
        message: 'Please review my documents before the deadline.',
        nowUtc: nowUtc,
      );
      expect(r.isValid, isFalse);
      expect(r.errorKey, 'bookingSlotRequired');
      expect(r.field, 'slot');
    });

    test('message is validated before slot', () {
      final r = BookingValidation.validate(
        service: consultation,
        message: 'short',
        nowUtc: nowUtc,
      );
      expect(r.errorKey, 'bookingMessageTooShort');
    });

    test('scheduled service with valid message and slot passes', () {
      final r = BookingValidation.validate(
        service: scheduled,
        message: 'Please review my documents before the deadline.',
        preferredStartUtc: nowUtc.add(const Duration(days: 3)),
        preferredEndUtc: nowUtc.add(const Duration(days: 3, hours: 1)),
        nowUtc: nowUtc,
      );
      expect(r.isValid, isTrue);
    });
  });

  group('BookingRecord round-trip', () {
    test('json round-trip preserves status and times', () {
      final record = BookingRecord(
        id: 'b1',
        serviceId: 'built-in-consultation',
        serviceTitle: 'RAD expert consultation',
        message: 'Need help with my case.',
        status: BookingStatus.submitted,
        createdAt: DateTime.utc(2026, 10, 20, 9, 30),
        preferredStartUtc: DateTime.utc(2026, 10, 25, 14),
        timeZoneId: 'Asia/Tehran',
      );
      final restored = BookingRecord.fromJson(record.toJson());
      expect(restored.id, 'b1');
      expect(restored.status, BookingStatus.submitted);
      expect(restored.preferredStartUtc, DateTime.utc(2026, 10, 25, 14));
      expect(restored.timeZoneId, 'Asia/Tehran');
    });

    test('unknown backend status maps to unknown, never confirmed', () {
      expect(
        BookingStatusX.fromString('confirmed_by_sms'),
        BookingStatus.unknown,
      );
      expect(BookingStatusX.fromString(null), BookingStatus.unknown);
      expect(BookingStatus.unknown.isConfirmed, isFalse);
    });

    test('only explicit confirmed status claims confirmation', () {
      expect(BookingStatus.confirmed.isConfirmed, isTrue);
      expect(BookingStatus.submitted.isConfirmed, isFalse);
      expect(BookingStatus.inReview.isConfirmed, isFalse);
    });
  });
}
