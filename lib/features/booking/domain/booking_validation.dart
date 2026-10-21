// Pure booking validation rules. No backend calls, no fabricated data.

import 'entities/service_booking.dart';

class BookingValidationResult {
  const BookingValidationResult({this.errorKey, this.field});

  /// Localization key for the failure, or null when valid.
  final String? errorKey;

  /// Which input failed (`message`, `slot`, ...).
  final String? field;

  bool get isValid => errorKey == null;
}

abstract final class BookingValidation {
  static const int minMessageLength = 10;
  static const int maxMessageLength = 1000;

  static const int minSlotMinutes = 15;
  static const int maxSlotMinutes = 24 * 60;

  static BookingValidationResult validateMessage(String? message) {
    final value = message?.trim() ?? '';
    if (value.isEmpty) {
      return const BookingValidationResult(
        errorKey: 'bookingMessageRequired',
        field: 'message',
      );
    }
    if (value.length < minMessageLength) {
      return const BookingValidationResult(
        errorKey: 'bookingMessageTooShort',
        field: 'message',
      );
    }
    if (value.length > maxMessageLength) {
      return const BookingValidationResult(
        errorKey: 'bookingMessageTooLong',
        field: 'message',
      );
    }
    return const BookingValidationResult();
  }

  /// A preferred slot must be a real future range of sane length.
  /// It is only a preference; the Backend decides the actual slot.
  static BookingValidationResult validatePreferredSlot({
    required DateTime? startUtc,
    required DateTime? endUtc,
    required DateTime nowUtc,
  }) {
    if (startUtc == null && endUtc == null) {
      return const BookingValidationResult(); // Optional.
    }
    if (startUtc == null || endUtc == null) {
      return const BookingValidationResult(
        errorKey: 'bookingSlotIncomplete',
        field: 'slot',
      );
    }
    if (!endUtc.isAfter(startUtc)) {
      return const BookingValidationResult(
        errorKey: 'bookingSlotOrder',
        field: 'slot',
      );
    }
    final minutes = endUtc.difference(startUtc).inMinutes;
    if (minutes < minSlotMinutes) {
      return const BookingValidationResult(
        errorKey: 'bookingSlotTooShort',
        field: 'slot',
      );
    }
    if (minutes > maxSlotMinutes) {
      return const BookingValidationResult(
        errorKey: 'bookingSlotTooLong',
        field: 'slot',
      );
    }
    if (startUtc.isBefore(nowUtc)) {
      return const BookingValidationResult(
        errorKey: 'bookingSlotPast',
        field: 'slot',
      );
    }
    return const BookingValidationResult();
  }

  /// Full request validation used by the booking form.
  static BookingValidationResult validate({
    required ServiceOffering service,
    required String? message,
    DateTime? preferredStartUtc,
    DateTime? preferredEndUtc,
    required DateTime nowUtc,
  }) {
    if (service.fulfillment == BookingFulfillment.staffScheduled &&
        preferredStartUtc == null) {
      // Staff-scheduled services need a preferred window; consultation does not.
      final slot = validatePreferredSlot(
        startUtc: preferredStartUtc,
        endUtc: preferredEndUtc,
        nowUtc: nowUtc,
      );
      if (!slot.isValid) return slot;
      return const BookingValidationResult(
        errorKey: 'bookingSlotRequired',
        field: 'slot',
      );
    }
    final messageResult = validateMessage(message);
    if (!messageResult.isValid) return messageResult;
    return validatePreferredSlot(
      startUtc: preferredStartUtc,
      endUtc: preferredEndUtc,
      nowUtc: nowUtc,
    );
  }
}
