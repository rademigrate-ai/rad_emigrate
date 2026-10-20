// Booking controller: catalog, submission, and history state.
// Repository is injected so tests can supply a fake without Supabase.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/booking_repository.dart';
import '../../domain/entities/service_booking.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return SupabaseBookingRepository(ref.watch(supabaseClientServiceProvider));
});

/// Locale-keyed service catalog (built-in + backend-published).
final bookingCatalogProvider =
    FutureProvider.family<ServiceCatalogResult, String>((ref, locale) async {
      return ref.watch(bookingRepositoryProvider).listServices(locale: locale);
    });

/// Auth-scoped booking history. Keyed by user id so logout / account switch
/// drops the previous identity's rows (A → logout → B isolation).
final bookingHistoryProvider =
    FutureProvider.autoDispose.family<List<BookingRecord>, String?>((ref, userId) async {
  if (userId == null || userId.isEmpty) return const [];
  return ref.watch(bookingRepositoryProvider).listMyBookings();
});

/// Convenience: resolves current auth uid and watches identity-bound history.
final currentBookingHistoryProvider =
    FutureProvider.autoDispose<List<BookingRecord>>((ref) async {
  final client = ref.watch(supabaseClientServiceProvider);
  final uid = client.isInitialized ? client.client.auth.currentUser?.id : null;
  return ref.watch(bookingHistoryProvider(uid).future);
});

enum BookingSubmitPhase { idle, submitting, success, failure }

class BookingSubmitState {
  const BookingSubmitState({
    this.phase = BookingSubmitPhase.idle,
    this.record,
    this.errorKey,
    this.backendUnavailable = false,
  });

  final BookingSubmitPhase phase;
  final BookingRecord? record;

  /// Localization key for a generic failure.
  final String? errorKey;

  /// True when the required Backend capability is not installed.
  final bool backendUnavailable;

  bool get isSubmitting => phase == BookingSubmitPhase.submitting;
}

/// Submit controller kept separate from list providers so history can be
/// refreshed after a successful request.
class BookingSubmitController extends StateNotifier<BookingSubmitState> {
  BookingSubmitController(this._repository) : super(const BookingSubmitState());

  final BookingRepository _repository;

  void reset() {
    state = const BookingSubmitState();
  }

  Future<BookingRecord?> submit({
    required ServiceOffering service,
    required BookingRequest request,
    required String locale,
  }) async {
    state = const BookingSubmitState(phase: BookingSubmitPhase.submitting);
    try {
      final record = await _repository.submitBooking(
        service: service,
        request: request,
        locale: locale,
      );
      state = BookingSubmitState(
        phase: BookingSubmitPhase.success,
        record: record,
      );
      return record;
    } on BookingBackendUnavailableException {
      state = const BookingSubmitState(
        phase: BookingSubmitPhase.failure,
        errorKey: 'bookingBackendUnavailable',
        backendUnavailable: true,
      );
      return null;
    } catch (_) {
      state = const BookingSubmitState(
        phase: BookingSubmitPhase.failure,
        errorKey: 'bookingGenericError',
      );
      return null;
    }
  }
}

final bookingSubmitControllerProvider =
    StateNotifierProvider<BookingSubmitController, BookingSubmitState>((ref) {
      return BookingSubmitController(ref.watch(bookingRepositoryProvider));
    });
