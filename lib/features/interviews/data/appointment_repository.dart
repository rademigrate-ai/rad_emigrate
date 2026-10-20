// Appointment data layer.
//
// No interview/appointment RPC is installed on any verified Backend branch
// today, so every operation probes for its capability and fails closed with
// an explicit unavailable exception instead of fabricating availability,
// confirmations, or embassy slots.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/rpc_compat.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/entities/interview_appointment.dart';

/// Thrown when the Backend capability a call needs is not installed.
class AppointmentBackendUnavailableException implements Exception {
  const AppointmentBackendUnavailableException(this.operation);

  final String operation;

  @override
  String toString() => 'AppointmentBackendUnavailableException($operation)';
}

/// Thrown for permission/validation/network failures (fail closed — never
/// reclassified as "unavailable").
class AppointmentException implements Exception {
  const AppointmentException(this.operation, [this.cause]);

  final String operation;
  final Object? cause;

  @override
  String toString() => 'AppointmentException($operation)';
}

/// Repository contract for interview/appointment scheduling.
abstract class AppointmentRepository {
  /// The current user's RAD session requests (Backend rows only).
  Future<AppointmentListResult> listMyAppointments();

  /// Submits a request for an internal RAD interview session.
  ///
  /// Only a real Backend response may produce a success; missing capability
  /// raises [AppointmentBackendUnavailableException].
  Future<InterviewAppointment> submitRadSession({
    required String title,
    required DateTime startUtc,
    required DateTime? endUtc,
    required String? ianaZoneId,
    required String notes,
  });

  /// Requests rescheduling of an existing Backend row.
  Future<void> reschedule({
    required String appointmentId,
    required DateTime startUtc,
    required DateTime? endUtc,
    required String? ianaZoneId,
    required String notes,
  });

  /// Cancels an existing Backend row.
  Future<void> cancel({required String appointmentId, required String reason});
}

class SupabaseAppointmentRepository implements AppointmentRepository {
  const SupabaseAppointmentRepository(this._service);

  static const String _listRpc = 'list_interview_requests';
  static const String _submitRpc = 'submit_interview_request';
  static const String _rescheduleRpc = 'reschedule_interview_request';
  static const String _cancelRpc = 'cancel_interview_request';

  final SupabaseClientService _service;

  @override
  Future<AppointmentListResult> listMyAppointments() async {
    if (!_service.isInitialized) {
      return const AppointmentListResult(
        appointments: [],
        capability: AppointmentCapability.unknown,
      );
    }
    final client = _service.client;
    if (client.auth.currentUser?.id == null) {
      return const AppointmentListResult(
        appointments: [],
        capability: AppointmentCapability.unknown,
      );
    }
    try {
      final rows = await client
          .rpc(_listRpc)
          .timeout(const Duration(seconds: 10));
      return AppointmentListResult(
        appointments: (rows as List<dynamic>)
            .map((row) => _fromRow(Map<String, dynamic>.from(row as Map)))
            .toList(growable: false),
        capability: AppointmentCapability.available,
      );
    } catch (error) {
      if (isRpcMissingException(error)) {
        return const AppointmentListResult(
          appointments: [],
          capability: AppointmentCapability.backendUnavailable,
        );
      }
      if (_isPermissionError(error)) {
        throw const AppointmentException(_listRpc);
      }
      return const AppointmentListResult(
        appointments: [],
        capability: AppointmentCapability.unknown,
      );
    }
  }

  @override
  Future<InterviewAppointment> submitRadSession({
    required String title,
    required DateTime startUtc,
    required DateTime? endUtc,
    required String? ianaZoneId,
    required String notes,
  }) async {
    final client = _requireClient();
    if (client.auth.currentUser?.id == null) {
      throw const AppointmentException('appointment_unauthenticated');
    }
    try {
      final rows = await client
          .rpc(
            _submitRpc,
            params: {
              'p_title': title,
              'p_start_utc': startUtc.toUtc().toIso8601String(),
              'p_end_utc': endUtc?.toUtc().toIso8601String(),
              'p_time_zone': ianaZoneId,
              'p_notes': notes,
            },
          )
          .timeout(const Duration(seconds: 15));
      return _fromRow(Map<String, dynamic>.from((rows as List).first as Map));
    } catch (error) {
      if (isRpcMissingException(error)) {
        throw const AppointmentBackendUnavailableException(_submitRpc);
      }
      throw AppointmentException(_submitRpc, error);
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
    final client = _requireClient();
    try {
      await client
          .rpc(
            _rescheduleRpc,
            params: {
              'p_appointment_id': appointmentId,
              'p_start_utc': startUtc.toUtc().toIso8601String(),
              'p_end_utc': endUtc?.toUtc().toIso8601String(),
              'p_time_zone': ianaZoneId,
              'p_notes': notes,
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      if (isRpcMissingException(error)) {
        throw const AppointmentBackendUnavailableException(_rescheduleRpc);
      }
      throw AppointmentException(_rescheduleRpc, error);
    }
  }

  @override
  Future<void> cancel({
    required String appointmentId,
    required String reason,
  }) async {
    final client = _requireClient();
    try {
      await client
          .rpc(
            _cancelRpc,
            params: {'p_appointment_id': appointmentId, 'p_reason': reason},
          )
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      if (isRpcMissingException(error)) {
        throw const AppointmentBackendUnavailableException(_cancelRpc);
      }
      throw AppointmentException(_cancelRpc, error);
    }
  }

  SupabaseClientService get _serviceRef => _service;

  SupabaseClient _requireClient() {
    if (!_serviceRef.isInitialized) {
      throw const AppointmentException('appointment_not_initialized');
    }
    return _serviceRef.client;
  }

  InterviewAppointment _fromRow(Map<String, dynamic> row) {
    return InterviewAppointment(
      id: row['id'] as String? ?? '',
      kind: AppointmentKindX.fromString(row['kind'] as String?),
      title: row['title'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
      startUtc:
          DateTime.tryParse(row['start_utc'] as String? ?? '') ??
          DateTime.tryParse(row['startUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endUtc: _parseFirst(row['end_utc'], row['endUtc']),
      ianaZoneId: row['time_zone'] as String? ?? row['ianaZoneId'] as String?,
      status: AppointmentStatusX.fromString(row['status'] as String?),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      backendManaged: true,
    );
  }

  static DateTime? _parseFirst(Object? a, Object? b) {
    final parsed = DateTime.tryParse(a?.toString() ?? '');
    if (parsed != null) return parsed;
    return DateTime.tryParse(b?.toString() ?? '');
  }

  static bool _isPermissionError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('permission') ||
        text.contains('42501') ||
        text.contains('unauthorized') ||
        text.contains('forbidden') ||
        text.contains('row-level security');
  }
}
