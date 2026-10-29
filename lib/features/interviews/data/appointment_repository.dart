// Appointment data layer.
//
// Uses the request-only appointment adapter. Missing capability fails closed;
// preferred times never imply availability, confirmations, or embassy slots.

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/rpc_compat.dart';
import '../../../core/supabase/rad_contract.dart';
import '../../../core/supabase/server_receipt.dart';
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
  SupabaseAppointmentRepository(this._service);

  static const String _listRpc = 'list_rad_appointments';
  static const String _submitRpc = 'submit_rad_appointment';
  static const String _rescheduleRpc = 'reschedule_rad_appointment';
  static const String _cancelRpc = 'cancel_rad_appointment';

  final SupabaseClientService _service;
  final Map<String, String> _pendingRequestKeys = {};

  @override
  Future<AppointmentListResult> listMyAppointments() async {
    if (!_service.isInitialized) {
      return const AppointmentListResult(
        appointments: [],
        capability: AppointmentCapability.unknown,
      );
    }
    final client = _service.client;
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      return const AppointmentListResult(
        appointments: [],
        capability: AppointmentCapability.unknown,
      );
    }
    try {
      final rows = await client
          .rpc(_listRpc)
          .timeout(const Duration(seconds: 10));
      if (client.auth.currentUser?.id != owner || rows is! List) {
        throw const AppointmentException('appointment_session_changed');
      }
      return AppointmentListResult(
        appointments: rows
            .map(
              (row) => _ownedRow(Map<String, dynamic>.from(row as Map), owner),
            )
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
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      throw const AppointmentException('appointment_unauthenticated');
    }
    final fingerprint = jsonEncode([
      owner,
      title,
      startUtc.toUtc().toIso8601String(),
      endUtc?.toUtc().toIso8601String(),
      ianaZoneId,
      notes,
    ]);
    final requestKey = _pendingRequestKeys.putIfAbsent(
      fingerprint,
      newRadRequestKey,
    );
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
              'p_idempotency_key': requestKey,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (rows is! List || rows.length != 1) {
        throw const AppointmentException('appointment_invalid_receipt');
      }
      if (client.auth.currentUser?.id != owner) {
        throw const AppointmentException('appointment_session_changed');
      }
      final receipt = _ownedRow(
        Map<String, dynamic>.from(rows.single as Map),
        owner,
      );
      if (receipt.kind != AppointmentKind.radSession ||
          receipt.status != AppointmentStatus.requested ||
          receipt.startUtc != startUtc.toUtc() ||
          receipt.title != title.trim() ||
          receipt.endUtc != endUtc?.toUtc() ||
          receipt.notes != notes ||
          receipt.ianaZoneId != _normalizedZone(ianaZoneId)) {
        throw const AppointmentException('appointment_mismatched_receipt');
      }
      _pendingRequestKeys.remove(fingerprint);
      return receipt;
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
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      throw const AppointmentException('appointment_unauthenticated');
    }
    try {
      final rows = await client
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
      final receipt = _mutationReceipt(rows, client, owner, appointmentId);
      if (receipt.status != AppointmentStatus.rescheduled ||
          receipt.startUtc != startUtc.toUtc() ||
          receipt.endUtc != endUtc?.toUtc() ||
          receipt.notes != notes ||
          (ianaZoneId != null &&
              ianaZoneId.trim().isNotEmpty &&
              receipt.ianaZoneId != _normalizedZone(ianaZoneId))) {
        throw const AppointmentException('appointment_mismatched_receipt');
      }
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
    final owner = client.auth.currentUser?.id;
    if (owner == null) {
      throw const AppointmentException('appointment_unauthenticated');
    }
    try {
      final rows = await client
          .rpc(
            _cancelRpc,
            params: {'p_appointment_id': appointmentId, 'p_reason': reason},
          )
          .timeout(const Duration(seconds: 15));
      final receipt = _mutationReceipt(rows, client, owner, appointmentId);
      if (receipt.status != AppointmentStatus.cancelled ||
          (rows as List).single['cancellation_reason'] != reason.trim()) {
        throw const AppointmentException('appointment_mismatched_receipt');
      }
    } catch (error) {
      if (isRpcMissingException(error)) {
        throw const AppointmentBackendUnavailableException(_cancelRpc);
      }
      throw AppointmentException(_cancelRpc, error);
    }
  }

  SupabaseClientService get _serviceRef => _service;

  InterviewAppointment _mutationReceipt(
    Object? rows,
    SupabaseClient client,
    String owner,
    String id,
  ) {
    if (client.auth.currentUser?.id != owner ||
        rows is! List ||
        rows.length != 1) {
      throw const AppointmentException('appointment_invalid_receipt');
    }
    final receipt = _ownedRow(
      Map<String, dynamic>.from(rows.single as Map),
      owner,
    );
    if (receipt.id != id || receipt.kind != AppointmentKind.radSession) {
      throw const AppointmentException('appointment_mismatched_receipt');
    }
    return receipt;
  }

  InterviewAppointment _ownedRow(Map<String, dynamic> row, String owner) {
    if (row['user_id'] != owner) {
      throw const AppointmentException('appointment_invalid_receipt');
    }
    return _fromRow(row);
  }

  static String? _normalizedZone(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  SupabaseClient _requireClient() {
    if (!_serviceRef.isInitialized) {
      throw const AppointmentException('appointment_not_initialized');
    }
    return _serviceRef.client;
  }

  InterviewAppointment _fromRow(Map<String, dynamic> row) {
    final id = requireServerId(row['id']);
    final status = AppointmentStatusX.fromString(row['status'] as String?);
    if (status == AppointmentStatus.unknown ||
        !AppointmentKind.values.any((kind) => kind.name == row['kind']) ||
        row['title'] is! String ||
        (row['title'] as String).trim().isEmpty) {
      throw const AppointmentException('appointment_invalid_receipt');
    }
    final start = requireServerTimestamp(row['start_utc'] ?? row['startUtc']);
    final endValue = row['end_utc'] ?? row['endUtc'];
    final end = endValue == null ? null : requireServerTimestamp(endValue);
    if (end != null && !end.isAfter(start)) {
      throw const AppointmentException('appointment_invalid_receipt');
    }
    return InterviewAppointment(
      id: id,
      kind: AppointmentKindX.fromString(row['kind'] as String),
      title: row['title'] as String,
      notes: row['notes'] as String? ?? '',
      startUtc: start,
      endUtc: end,
      ianaZoneId: row['time_zone'] as String? ?? row['ianaZoneId'] as String?,
      status: status,
      createdAt: requireServerTimestamp(row['created_at']),
      backendManaged: true,
    );
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
