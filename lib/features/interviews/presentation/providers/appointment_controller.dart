// Appointment controller: list, submit, reschedule, cancel state.
// Repository is injected so tests can supply a fake without Supabase.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/appointment_repository.dart';
import '../../domain/entities/interview_appointment.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return SupabaseAppointmentRepository(
    ref.watch(supabaseClientServiceProvider),
  );
});

/// Current user's Backend-managed appointment rows.
/// autoDispose + client watch: session change drops cache (A→logout→B).
final appointmentListProvider =
    FutureProvider.autoDispose<AppointmentListResult>((ref) async {
      ref.watch(supabaseClientServiceProvider);
      return ref.watch(appointmentRepositoryProvider).listMyAppointments();
    });

enum AppointmentActionPhase { idle, running, success, failure }

class AppointmentActionState {
  const AppointmentActionState({
    this.phase = AppointmentActionPhase.idle,
    this.appointment,
    this.errorKey,
    this.backendUnavailable = false,
  });

  final AppointmentActionPhase phase;
  final InterviewAppointment? appointment;
  final String? errorKey;
  final bool backendUnavailable;

  bool get isRunning => phase == AppointmentActionPhase.running;
}

/// Submit / reschedule / cancel controller.
class AppointmentController extends StateNotifier<AppointmentActionState> {
  AppointmentController(this._repository)
    : super(const AppointmentActionState());

  final AppointmentRepository _repository;

  void reset() {
    state = const AppointmentActionState();
  }

  Future<InterviewAppointment?> submit({
    required String title,
    required DateTime startUtc,
    required DateTime? endUtc,
    required String? ianaZoneId,
    required String notes,
  }) async {
    state = const AppointmentActionState(phase: AppointmentActionPhase.running);
    try {
      final appointment = await _repository.submitRadSession(
        title: title,
        startUtc: startUtc,
        endUtc: endUtc,
        ianaZoneId: ianaZoneId,
        notes: notes,
      );
      state = AppointmentActionState(
        phase: AppointmentActionPhase.success,
        appointment: appointment,
      );
      return appointment;
    } on AppointmentBackendUnavailableException {
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.failure,
        errorKey: 'appointmentBackendUnavailable',
        backendUnavailable: true,
      );
      return null;
    } catch (_) {
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.failure,
        errorKey: 'appointmentGenericError',
      );
      return null;
    }
  }

  /// Reschedules an open appointment; capability failure surfaces explicitly.
  Future<bool> reschedule({
    required String appointmentId,
    required DateTime startUtc,
    required DateTime? endUtc,
    required String? ianaZoneId,
    required String notes,
  }) async {
    state = const AppointmentActionState(phase: AppointmentActionPhase.running);
    try {
      await _repository.reschedule(
        appointmentId: appointmentId,
        startUtc: startUtc,
        endUtc: endUtc,
        ianaZoneId: ianaZoneId,
        notes: notes,
      );
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.success,
      );
      return true;
    } on AppointmentBackendUnavailableException {
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.failure,
        errorKey: 'appointmentRescheduleUnavailable',
        backendUnavailable: true,
      );
      return false;
    } catch (_) {
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.failure,
        errorKey: 'appointmentGenericError',
      );
      return false;
    }
  }

  Future<bool> cancel({
    required String appointmentId,
    required String reason,
  }) async {
    state = const AppointmentActionState(phase: AppointmentActionPhase.running);
    try {
      await _repository.cancel(appointmentId: appointmentId, reason: reason);
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.success,
      );
      return true;
    } on AppointmentBackendUnavailableException {
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.failure,
        errorKey: 'appointmentCancelUnavailable',
        backendUnavailable: true,
      );
      return false;
    } catch (_) {
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.failure,
        errorKey: 'appointmentGenericError',
      );
      return false;
    }
  }
}

final appointmentControllerProvider =
    StateNotifierProvider<AppointmentController, AppointmentActionState>((ref) {
      return AppointmentController(ref.watch(appointmentRepositoryProvider));
    });
