// Service and consultation booking domain foundation.
//
// Pure domain models only. Nothing here fabricates availability, prices, or
// confirmations: a booking is only ever "confirmed" when a real Backend
// response says so.

/// Broad grouping for RAD service offerings.
enum ServiceCategory {
  consultation,
  documentReview,
  applicationSupport,
  interviewPreparation,
  other,
}

extension ServiceCategoryX on ServiceCategory {
  String get key => name;

  static ServiceCategory fromString(String? value) {
    if (value == null || value.isEmpty) return ServiceCategory.other;
    return ServiceCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ServiceCategory.other,
    );
  }
}

/// How a booking for this service is fulfilled.
///
/// [humanConsultation] maps to the verified consultation request backend.
/// [staffScheduled] requires a scheduling Backend that is not yet available.
enum BookingFulfillment { humanConsultation, staffScheduled }

/// A bookable RAD service.
///
/// Price is intentionally absent: no approved pricing contract exists.
class ServiceOffering {
  const ServiceOffering({
    required this.id,
    required this.slug,
    required this.title,
    required this.category,
    required this.fulfillment,
    this.description = '',
    this.durationMinutes,
    this.requiresAuth = true,
    this.backendManaged = false,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final ServiceCategory category;
  final BookingFulfillment fulfillment;

  /// Expected duration when the Backend publishes one; never invented.
  final int? durationMinutes;

  /// Booking requests must come from an authenticated user.
  final bool requiresAuth;

  /// True when the offering was returned by a Backend catalog RPC rather
  /// than being a built-in verified entry.
  final bool backendManaged;

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title': title,
    'description': description,
    'category': category.name,
    'fulfillment': fulfillment.name,
    'durationMinutes': durationMinutes,
    'requiresAuth': requiresAuth,
    'backendManaged': backendManaged,
  };

  factory ServiceOffering.fromJson(Map<String, dynamic> json) {
    return ServiceOffering(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: ServiceCategoryX.fromString(json['category'] as String?),
      fulfillment: (json['fulfillment'] as String?) == 'staffScheduled'
          ? BookingFulfillment.staffScheduled
          : BookingFulfillment.humanConsultation,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      requiresAuth: json['requiresAuth'] as bool? ?? true,
      backendManaged: json['backendManaged'] as bool? ?? false,
    );
  }
}

/// Lifecycle of a booking request as reported by the Backend.
enum BookingStatus {
  submitted,
  inReview,
  confirmed,
  rescheduled,
  cancelled,
  completed,
  unknown,
}

extension BookingStatusX on BookingStatus {
  String get key => name;

  static BookingStatus fromString(String? value) {
    if (value == null || value.isEmpty) return BookingStatus.unknown;
    return BookingStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BookingStatus.unknown,
    );
  }

  /// Only an explicit Backend "confirmed" state may claim confirmation.
  bool get isConfirmed => this == BookingStatus.confirmed;

  bool get isOpen =>
      this == BookingStatus.submitted ||
      this == BookingStatus.inReview ||
      this == BookingStatus.rescheduled;
}

/// A booking request created by the user.
class BookingRequest {
  const BookingRequest({
    required this.serviceId,
    required this.message,
    this.preferredStartUtc,
    this.preferredEndUtc,
    this.timeZoneId,
  });

  final String serviceId;
  final String message;

  /// Preferred slot in UTC when the user picked one. Never interpreted as
  /// availability — the Backend decides the actual slot.
  final DateTime? preferredStartUtc;
  final DateTime? preferredEndUtc;

  /// IANA timezone id for the picked slot (e.g. `Asia/Tehran`).
  final String? timeZoneId;

  bool get hasPreferredSlot =>
      preferredStartUtc != null && preferredEndUtc != null;

  Map<String, dynamic> toJson() => {
    'serviceId': serviceId,
    'message': message,
    'preferredStartUtc': preferredStartUtc?.toUtc().toIso8601String(),
    'preferredEndUtc': preferredEndUtc?.toUtc().toIso8601String(),
    'timeZoneId': timeZoneId,
  };
}

/// A booking record owned by the current user.
class BookingRecord {
  const BookingRecord({
    required this.id,
    required this.serviceId,
    required this.serviceTitle,
    required this.status,
    required this.createdAt,
    this.message = '',
    this.preferredStartUtc,
    this.timeZoneId,
    this.updatedAt,
  });

  final String id;
  final String serviceId;
  final String serviceTitle;
  final String message;
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? preferredStartUtc;
  final String? timeZoneId;

  BookingRecord copyWith({BookingStatus? status, DateTime? updatedAt}) {
    return BookingRecord(
      id: id,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      message: message,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferredStartUtc: preferredStartUtc,
      timeZoneId: timeZoneId,
    );
  }

  factory BookingRecord.fromJson(Map<String, dynamic> json) {
    return BookingRecord(
      id: json['id'] as String? ?? '',
      serviceId: json['serviceId'] as String? ?? '',
      serviceTitle: json['serviceTitle'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: BookingStatusX.fromString(json['status'] as String?),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      preferredStartUtc: json['preferredStartUtc'] != null
          ? DateTime.tryParse(json['preferredStartUtc'] as String)
          : null,
      timeZoneId: json['timeZoneId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'serviceId': serviceId,
    'serviceTitle': serviceTitle,
    'message': message,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    'preferredStartUtc': preferredStartUtc?.toUtc().toIso8601String(),
    'timeZoneId': timeZoneId,
  };
}

/// Explicit capability state for booking backend operations.
enum BookingCapability { available, backendUnavailable, unknown }

/// Result of listing services: distinguishes real data from "not deployed".
class ServiceCatalogResult {
  const ServiceCatalogResult({
    required this.services,
    required this.capability,
  });

  final List<ServiceOffering> services;
  final BookingCapability capability;

  bool get isEmpty => services.isEmpty;
}
