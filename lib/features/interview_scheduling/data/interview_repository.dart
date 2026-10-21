import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/rad_contract.dart';
import '../domain/entities/interview_slot.dart';

class InterviewBackendUnavailableException implements Exception {
  const InterviewBackendUnavailableException(this.operation);
  final String operation;
  @override
  String toString() => 'InterviewBackendUnavailableException($operation)';
}

abstract class InterviewRepository {
  Future<List<InterviewSlot>> listAvailableSlots({required String locale});
  Future<InterviewBookingRecord> scheduleInterview({
    required String slotId,
    required String notes,
    required String locale,
  });
}

class SupabaseInterviewRepository implements InterviewRepository {
  const SupabaseInterviewRepository(this._service);

  final SupabaseClientService _service;

  @override
  Future<List<InterviewSlot>> listAvailableSlots({
    required String locale,
  }) async {
    if (!_service.isInitialized) {
      throw const InterviewBackendUnavailableException('list_interview_slots');
    }
    try {
      final res = await _service.client.rpc(
        'list_interview_slots',
        params: {'locale': locale},
      );
      final data = (res is Map && res['data'] is List)
          ? res['data'] as List
          : [];
      return data
          .map((e) => InterviewSlot.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Backend RPC not installed or network offline -> fail closed explicitly
      throw const InterviewBackendUnavailableException('list_interview_slots');
    }
  }

  @override
  Future<InterviewBookingRecord> scheduleInterview({
    required String slotId,
    required String notes,
    required String locale,
  }) async {
    if (!_service.isInitialized) {
      throw const InterviewBackendUnavailableException('schedule_interview');
    }
    try {
      final res = await _service.client.rpc(
        'schedule_interview',
        params: {'slot_id': slotId, 'notes': notes, 'locale': locale},
      );
      return parseInterviewReceipt(res, slotId);
    } catch (_) {
      throw const InterviewBackendUnavailableException('schedule_interview');
    }
  }
}

InterviewBookingRecord parseInterviewReceipt(Object? response, String slotId) {
  final data = response is Map ? response['data'] : null;
  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  if (data is! Map ||
      data['id'] is! String ||
      !uuid.hasMatch(data['id'] as String) ||
      data['slot_id'] != slotId ||
      !{
        'submitted',
        'pending_confirmation',
        'confirmed',
      }.contains(data['status'])) {
    throw const FormatException('invalid_interview_receipt');
  }
  DateTime timestamp(String key) {
    final value = data[key];
    requireRadContract('Timestamp', value);
    final parsed = value is String && value.endsWith('Z')
        ? DateTime.tryParse(value)
        : null;
    if (parsed == null) {
      throw const FormatException('invalid_interview_receipt');
    }
    return parsed.toUtc();
  }

  return InterviewBookingRecord(
    id: data['id'] as String,
    slotId: slotId,
    scheduledStartUtc: timestamp('start_utc'),
    status: data['status'] as String,
    createdAtUtc: timestamp('created_at'),
  );
}
