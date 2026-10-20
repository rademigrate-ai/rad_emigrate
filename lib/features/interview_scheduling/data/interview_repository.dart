import '../../../core/supabase/supabase_client.dart';
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
      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      return InterviewBookingRecord(
        id: data['id'] as String? ?? 'intv-pending',
        slotId: slotId,
        scheduledStartUtc:
            DateTime.tryParse(data['start_utc'] as String? ?? '') ??
            DateTime.now().toUtc(),
        status: data['status'] as String? ?? 'pending_confirmation',
        createdAtUtc: DateTime.now().toUtc(),
      );
    } catch (_) {
      throw const InterviewBackendUnavailableException('schedule_interview');
    }
  }
}
