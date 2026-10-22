// Booking data layer.
//
// Integrates with the verified consultation backend where one exists and
// fails closed with explicit capability states everywhere else. A booking is
// never fabricated: if the required RPC is not installed, the caller receives
// [BookingBackendUnavailableException] and the UI shows an explicit
// unavailable state.

import '../../../core/supabase/rpc_compat.dart';
import '../../../core/supabase/server_receipt.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/entities/service_booking.dart';

/// Thrown when the Backend capability a call needs is not installed.
class BookingBackendUnavailableException implements Exception {
  const BookingBackendUnavailableException(this.operation);

  final String operation;

  @override
  String toString() => 'BookingBackendUnavailableException($operation)';
}

/// Thrown for permission/validation/network failures (fail closed — never
/// reclassified as "unavailable" and never silently ignored).
class BookingException implements Exception {
  const BookingException(this.operation, [this.cause]);

  final String operation;
  final Object? cause;

  @override
  String toString() => 'BookingException($operation)';
}

/// Repository contract for service booking.
abstract class BookingRepository {
  /// Built-in verified services plus any Backend-published catalog rows.
  Future<ServiceCatalogResult> listServices({required String locale});

  /// Submits a booking request. Returns the Backend record id.
  ///
  /// Only a real Backend response may produce a success; missing capability
  /// raises [BookingBackendUnavailableException].
  Future<BookingRecord> submitBooking({
    required ServiceOffering service,
    required BookingRequest request,
    required String locale,
  });

  /// The current user's booking history (Backend-owned rows only).
  Future<List<BookingRecord>> listMyBookings();
}

/// Supabase-backed implementation.
///
/// Consultation-type bookings reuse the verified `submit_consultation_request`
/// RPC and the `consultation_requests` table (RLS: owner read). Staff-scheduled
/// bookings require RPCs that are not yet installed and fail closed with
/// [BookingBackendUnavailableException].
class SupabaseBookingRepository implements BookingRepository {
  const SupabaseBookingRepository(this._service);

  static const String _catalogRpc = 'list_service_catalog';
  static const String _bookingRpc = 'submit_booking_request';
  static const String _historyRpc = 'list_my_booking_requests';

  final SupabaseClientService _service;

  /// The single built-in service backed by verified Backend behavior.
  ///
  /// This is a real capability: `submit_consultation_request` is installed
  /// with rate limiting (Stage 1 Migration 4) and `consultation_requests`
  /// is owner-read under RLS.
  ServiceOffering _builtInConsultation(String locale) {
    return ServiceOffering(
      id: 'built-in-consultation',
      slug: 'consultation',
      title: locale == 'fa' ? 'مشاوره تخصصی RAD' : 'RAD expert consultation',
      description: locale == 'fa'
          ? 'درخواست گفتگوی انسانی با کارشناسان RAD درباره وضعیت مهاجرتی شما.'
          : 'Request a human conversation with a RAD advisor about your immigration situation.',
      category: ServiceCategory.consultation,
      fulfillment: BookingFulfillment.humanConsultation,
      durationMinutes: null, // Never invented.
      backendManaged: false,
    );
  }

  @override
  Future<ServiceCatalogResult> listServices({required String locale}) async {
    final builtIn = _builtInConsultation(locale);
    if (!_service.isInitialized) {
      // Unauthenticated catalog view: only the built-in description is safe.
      return ServiceCatalogResult(
        services: [builtIn],
        capability: BookingCapability.unknown,
      );
    }
    try {
      final rows = await _service.client
          .rpc(_catalogRpc, params: {'p_locale': locale == 'fa' ? 'fa' : 'en'})
          .timeout(const Duration(seconds: 10));
      final backendServices = <ServiceOffering>[];
      for (final row in (rows as List<dynamic>)) {
        final map = Map<String, dynamic>.from(row as Map);
        backendServices.add(
          ServiceOffering(
            id: requireServerId(map['id']),
            slug: map['slug'] as String? ?? '',
            title: map['title'] as String? ?? '',
            description: map['description'] as String? ?? '',
            category: ServiceCategoryX.fromString(map['category'] as String?),
            fulfillment: (map['fulfillment'] as String?) == 'staffScheduled'
                ? BookingFulfillment.staffScheduled
                : BookingFulfillment.humanConsultation,
            durationMinutes: (map['duration_minutes'] as num?)?.toInt(),
            backendManaged: true,
          ),
        );
      }
      return ServiceCatalogResult(
        services: [builtIn, ...backendServices],
        capability: BookingCapability.available,
      );
    } catch (error) {
      if (isRpcMissingException(error)) {
        // Catalog RPC not installed: the built-in service is still real.
        return ServiceCatalogResult(
          services: [builtIn],
          capability: BookingCapability.backendUnavailable,
        );
      }
      if (_isPermissionError(error)) {
        throw const BookingException(_catalogRpc);
      }
      // Network/timeout degrade to the built-in catalog with an explicit
      // capability marker; history and submission still fail closed.
      return ServiceCatalogResult(
        services: [builtIn],
        capability: BookingCapability.unknown,
      );
    }
  }

  @override
  Future<BookingRecord> submitBooking({
    required ServiceOffering service,
    required BookingRequest request,
    required String locale,
  }) async {
    if (!_service.isInitialized) {
      throw const BookingException('booking_not_initialized');
    }
    final client = _service.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw const BookingException('booking_unauthenticated');

    if (service.fulfillment == BookingFulfillment.humanConsultation) {
      // Real, verified backend path: consultation requests.
      final topic = service.backendManaged
          ? '${service.title} — booking request'
          : (locale == 'fa'
                ? 'درخواست مشاوره RAD'
                : 'RAD consultation request');
      try {
        final rpcResult = await client.rpc(
          'submit_consultation_request',
          params: {'p_topic': topic, 'p_message': request.message},
        );
        final serverId = rpcResult is String ? rpcResult : null;
        if (serverId == null ||
            !RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ).hasMatch(serverId)) {
          throw const BookingException('consultation_missing_server_id');
        }
        if (client.auth.currentUser?.id != uid) {
          throw const BookingException('booking_session_changed');
        }
        // The legacy RPC returns only an ID. Read the owner-scoped persisted
        // receipt; a local clock cannot stand in for the server's created_at.
        final rows = await client
            .from('consultation_requests')
            .select('id, status, created_at')
            .eq('id', serverId)
            .eq('user_id', uid)
            .limit(2)
            .timeout(const Duration(seconds: 10));
        if (client.auth.currentUser?.id != uid ||
            rows.length != 1 ||
            rows.single['id'] != serverId) {
          throw const BookingException('consultation_invalid_receipt');
        }
        final receipt = rows.single;
        final status = _consultationStatus(receipt['status'] as String?);
        if (status == BookingStatus.unknown) {
          throw const BookingException('consultation_invalid_receipt');
        }
        final createdAt = requireServerTimestamp(receipt['created_at']);
        return BookingRecord(
          id: serverId,
          serviceId: service.id,
          serviceTitle: service.title,
          message: request.message,
          status: status,
          createdAt: createdAt,
          preferredStartUtc: null,
          timeZoneId: null,
        );
      } catch (error) {
        if (error is BookingException ||
            error is BookingBackendUnavailableException) {
          rethrow;
        }
        if (isRpcMissingException(error)) {
          throw const BookingBackendUnavailableException(
            'submit_consultation_request',
          );
        }
        throw BookingException('submit_consultation_request', error);
      }
    }

    // Staff-scheduled bookings require a Backend that does not exist yet.
    try {
      final rows = await client
          .rpc(
            _bookingRpc,
            params: {
              'p_service_id': service.id,
              'p_message': request.message,
              'p_preferred_start_utc': request.preferredStartUtc
                  ?.toUtc()
                  .toIso8601String(),
              'p_preferred_end_utc': request.preferredEndUtc
                  ?.toUtc()
                  .toIso8601String(),
              'p_time_zone': request.timeZoneId,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (rows is! List || rows.length != 1) {
        throw const BookingException('booking_invalid_receipt');
      }
      final row = Map<String, dynamic>.from(rows.single as Map);
      final id = requireServerId(row['id']);
      final status = BookingStatusX.fromString(row['status'] as String?);
      if (row['service_id'] != service.id || status == BookingStatus.unknown) {
        throw const BookingException('booking_invalid_receipt');
      }
      final createdAt = requireServerTimestamp(row['created_at']);
      return BookingRecord(
        id: id,
        serviceId: service.id,
        serviceTitle: service.title,
        message: request.message,
        status: status,
        createdAt: createdAt,
        preferredStartUtc: row['preferred_start_utc'] == null
            ? null
            : requireServerTimestamp(row['preferred_start_utc']),
        timeZoneId: row['time_zone'] as String?,
      );
    } catch (error) {
      if (error is BookingException) rethrow;
      if (isRpcMissingException(error)) {
        throw const BookingBackendUnavailableException(_bookingRpc);
      }
      throw BookingException(_bookingRpc, error);
    }
  }

  @override
  Future<List<BookingRecord>> listMyBookings() async {
    if (!_service.isInitialized) return const [];
    final client = _service.client;
    if (client.auth.currentUser?.id == null) return const [];
    try {
      final rows = await client
          .rpc(_historyRpc)
          .timeout(const Duration(seconds: 10));
      return (rows as List<dynamic>)
          .map((row) {
            final map = Map<String, dynamic>.from(row as Map);
            return BookingRecord(
              id: requireServerId(map['id']),
              serviceId: map['service_id'] as String? ?? '',
              serviceTitle: map['service_title'] as String? ?? '',
              message: map['message'] as String? ?? '',
              status: BookingStatusX.fromString(map['status'] as String?),
              createdAt: requireServerTimestamp(map['created_at']),
              updatedAt: map['updated_at'] != null
                  ? DateTime.tryParse(map['updated_at'] as String)
                  : null,
            );
          })
          .toList(growable: false);
    } catch (error) {
      if (isRpcMissingException(error)) {
        // Fall back to the verified consultation history table.
        return _consultationHistory();
      }
      if (_isPermissionError(error)) {
        throw const BookingException(_historyRpc);
      }
      rethrow;
    }
  }

  /// Verified fallback: owner-scoped consultation request rows.
  Future<List<BookingRecord>> _consultationHistory() async {
    final client = _service.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await client
          .from('consultation_requests')
          .select('id, topic, message, status, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List<dynamic>)
          .map((row) {
            final map = Map<String, dynamic>.from(row as Map);
            return BookingRecord(
              id: requireServerId(map['id']),
              serviceId: 'built-in-consultation',
              serviceTitle: map['topic'] as String? ?? '',
              message: map['message'] as String? ?? '',
              status: _consultationStatus(map['status'] as String?),
              createdAt: requireServerTimestamp(map['created_at']),
            );
          })
          .toList(growable: false);
    } catch (error) {
      if (_isPermissionError(error)) {
        throw const BookingException('consultation_history');
      }
      rethrow;
    }
  }

  /// Consultation statuses map honestly: `contacted` keeps the request open
  /// (staff engaged, no confirmation claimed); `closed` completes it.
  static BookingStatus _consultationStatus(String? value) {
    switch (value) {
      case 'submitted':
        return BookingStatus.submitted;
      case 'in_review':
      case 'contacted':
        return BookingStatus.inReview;
      case 'closed':
        return BookingStatus.completed;
      default:
        return BookingStatus.unknown;
    }
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
