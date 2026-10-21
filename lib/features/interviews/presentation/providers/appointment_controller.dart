// Appointment controller: list, submit, reschedule, cancel state.
// Repository is injected so tests can supply a fake without Supabase.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/appointment_repository.dart';
import '../../domain/entities/interview_appointment.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return SupabaseAppointmentRepository(
    ref.watch(supabaseClientServiceProvider),
  );
});

/// Current user's Backend-managed appointment rows, keyed by auth uid so
/// A → logout → B never reuses the previous identity cache.
final appointmentListProvider = FutureProvider.autoDispose
    .family<AppointmentListResult, String?>((ref, userId) async {
      if (userId == null || userId.isEmpty) {
        return const AppointmentListResult(
          appointments: [],
          capability: AppointmentCapability.unknown,
        );
      }
      const empty = AppointmentListResult(
        appointments: [],
        capability: AppointmentCapability.unknown,
      );
      if (ref.watch(authenticatedUserIdProvider) != userId) return empty;
      final service = ref.read(supabaseClientServiceProvider);
      bool sameSession() =>
          !service.isInitialized ||
          service.client.auth.currentUser?.id == userId;
      if (!sameSession()) return empty;
      var active = true;
      ref.onDispose(() => active = false);
      final rows = await ref
          .watch(appointmentRepositoryProvider)
          .listMyAppointments();
      return active && sameSession() ? rows : empty;
    });

/// Convenience provider that binds to the live session uid.
final currentAppointmentListProvider =
    Provider.autoDispose<AsyncValue<AppointmentListResult>>((ref) {
      final uid = ref.watch(authenticatedUserIdProvider);
      return ref.watch(appointmentListProvider(uid));
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
  AppointmentController(this._repository, {bool Function()? isCurrent})
    : _isCurrent = isCurrent ?? (() => true),
      super(const AppointmentActionState());

  final AppointmentRepository _repository;
  final bool Function() _isCurrent;
  bool get _active => mounted && _isCurrent();

  void reset() {
    if (!_active) return;
    state = const AppointmentActionState();
  }

  Future<InterviewAppointment?> submit({
    required String title,
    required DateTime startUtc,
    required DateTime? endUtc,
    required String? ianaZoneId,
    required String notes,
  }) async {
    if (!_active) return null;
    state = const AppointmentActionState(phase: AppointmentActionPhase.running);
    try {
      final appointment = await _repository.submitRadSession(
        title: title,
        startUtc: startUtc,
        endUtc: endUtc,
        ianaZoneId: ianaZoneId,
        notes: notes,
      );
      if (!_active) return null;
      state = AppointmentActionState(
        phase: AppointmentActionPhase.success,
        appointment: appointment,
      );
      return appointment;
    } on AppointmentBackendUnavailableException {
      if (!_active) return null;
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.failure,
        errorKey: 'appointmentBackendUnavailable',
        backendUnavailable: true,
      );
      return null;
    } catch (_) {
      if (!_active) return null;
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
    if (!_active) return false;
    state = const AppointmentActionState(phase: AppointmentActionPhase.running);
    try {
      await _repository.reschedule(
        appointmentId: appointmentId,
        startUtc: startUtc,
        endUtc: endUtc,
        ianaZoneId: ianaZoneId,
        notes: notes,
      );
      if (!_active) return false;
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.success,
      );
      return true;
    } on AppointmentBackendUnavailableException {
      if (!_active) return false;
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.failure,
        errorKey: 'appointmentRescheduleUnavailable',
        backendUnavailable: true,
      );
      return false;
    } catch (_) {
      if (!_active) return false;
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
    if (!_active) return false;
    state = const AppointmentActionState(phase: AppointmentActionPhase.running);
    try {
      await _repository.cancel(appointmentId: appointmentId, reason: reason);
      if (!_active) return false;
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.success,
      );
      return true;
    } on AppointmentBackendUnavailableException {
      if (!_active) return false;
      state = const AppointmentActionState(
        phase: AppointmentActionPhase.failure,
        errorKey: 'appointmentCancelUnavailable',
        backendUnavailable: true,
      );
      return false;
    } catch (_) {
      if (!_active) return false;
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
      final identity = ref.watch(authenticatedUserIdProvider);
      final service = ref.watch(supabaseClientServiceProvider);
      return AppointmentController(
        ref.watch(appointmentRepositoryProvider),
        isCurrent: () =>
            identity != null &&
            identity.isNotEmpty &&
            ref.read(authenticatedUserIdProvider) == identity &&
            (!service.isInitialized ||
                service.client.auth.currentUser?.id == identity),
      );
    });
