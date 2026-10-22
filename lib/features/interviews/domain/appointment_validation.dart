// Pure appointment validation rules. No backend calls, no fabricated data.

import 'entities/interview_appointment.dart';

class AppointmentValidationResult {
  const AppointmentValidationResult({this.errorKey, this.field});

  /// Localization key for the failure, or null when valid.
  final String? errorKey;

  /// Which input failed (`title`, `start`, `end`, ...).
  final String? field;

  bool get isValid => errorKey == null;
}

abstract final class AppointmentValidation {
  static const int minTitleLength = 4;
  static const int maxTitleLength = 120;
  static const int maxNotesLength = 600;
  static const int minDurationMinutes = 15;
  static const int maxDurationMinutes = 4 * 60;

  static AppointmentValidationResult validateTitle(String? title) {
    final value = title?.trim() ?? '';
    if (value.isEmpty) {
      return const AppointmentValidationResult(
        errorKey: 'appointmentTitleRequired',
        field: 'title',
      );
    }
    if (value.length < minTitleLength) {
      return const AppointmentValidationResult(
        errorKey: 'appointmentTitleTooShort',
        field: 'title',
      );
    }
    if (value.length > maxTitleLength) {
      return const AppointmentValidationResult(
        errorKey: 'appointmentTitleTooLong',
        field: 'title',
      );
    }
    return const AppointmentValidationResult();
  }

  static AppointmentValidationResult validateNotes(String? notes) {
    final value = notes?.trim() ?? '';
    if (value.length > maxNotesLength) {
      return const AppointmentValidationResult(
        errorKey: 'appointmentNotesTooLong',
        field: 'notes',
      );
    }
    return const AppointmentValidationResult();
  }

  /// The requested slot must be in the future (civil time interpreted in the
  /// selected zone is converted to UTC before validation).
  static AppointmentValidationResult validateStart({
    required DateTime? startUtc,
    required DateTime nowUtc,
  }) {
    if (startUtc == null) {
      return const AppointmentValidationResult(
        errorKey: 'appointmentStartRequired',
        field: 'start',
      );
    }
    if (startUtc.isBefore(nowUtc)) {
      return const AppointmentValidationResult(
        errorKey: 'appointmentStartPast',
        field: 'start',
      );
    }
    return const AppointmentValidationResult();
  }

  static AppointmentValidationResult validateEnd({
    required DateTime? endUtc,
    required DateTime startUtc,
  }) {
    if (endUtc == null) {
      return const AppointmentValidationResult(); // Optional.
    }
    if (!endUtc.isAfter(startUtc)) {
      return const AppointmentValidationResult(
        errorKey: 'appointmentEndBeforeStart',
        field: 'end',
      );
    }
    final minutes = endUtc.difference(startUtc).inMinutes;
    if (minutes < minDurationMinutes) {
      return const AppointmentValidationResult(
        errorKey: 'appointmentTooShort',
        field: 'end',
      );
    }
    if (minutes > maxDurationMinutes) {
      return const AppointmentValidationResult(
        errorKey: 'appointmentTooLong',
        field: 'end',
      );
    }
    return const AppointmentValidationResult();
  }

  static AppointmentValidationResult validate({
    required AppointmentKind kind,
    required String? title,
    String? notes,
    DateTime? startUtc,
    DateTime? endUtc,
    required DateTime nowUtc,
  }) {
    final titleResult = validateTitle(title);
    if (!titleResult.isValid) return titleResult;

    final notesResult = validateNotes(notes);
    if (!notesResult.isValid) return notesResult;

    final startResult = validateStart(startUtc: startUtc, nowUtc: nowUtc);
    if (!startResult.isValid) return startResult;

    if (endUtc != null) {
      final endResult = validateEnd(endUtc: endUtc, startUtc: startUtc!);
      if (!endResult.isValid) return endResult;
    }

    // External government appointments are user records only: RAD never
    // books them, so the request path refuses them outright.
    if (kind == AppointmentKind.externalGovernment) {
      return const AppointmentValidationResult(
        errorKey: 'appointmentExternalNotBookable',
        field: 'kind',
      );
    }
    return const AppointmentValidationResult();
  }
}
