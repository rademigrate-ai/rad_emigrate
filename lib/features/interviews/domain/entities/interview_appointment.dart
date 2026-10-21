// Interview / appointment scheduling domain foundation.
//
// Pure models. Nothing here claims embassy availability or government
// appointments: RAD only schedules its own internal interview sessions.

/// What kind of appointment this is.
///
/// [radSession] is an internal RAD interview/consultation session that the
/// user can request from RAD staff. [externalGovernment] records a government
/// or embassy appointment the user already has — RAD never books, confirms,
/// or displays availability for those, so this kind is display-only.
enum AppointmentKind { radSession, externalGovernment }

extension AppointmentKindX on AppointmentKind {
  String get key => name;
  static AppointmentKind fromString(String? value) {
    if (value == 'externalGovernment') {
      return AppointmentKind.externalGovernment;
    }
    return AppointmentKind.radSession;
  }
}

/// Lifecycle reported by the Backend (or local record state).
enum AppointmentStatus {
  requested,
  inReview,
  confirmed,
  rescheduled,
  cancelled,
  completed,
  unknown,
}

extension AppointmentStatusX on AppointmentStatus {
  String get key => name;

  static AppointmentStatus fromString(String? value) {
    if (value == null || value.isEmpty) return AppointmentStatus.unknown;
    return AppointmentStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppointmentStatus.unknown,
    );
  }

  /// Only an explicit Backend "confirmed" may claim confirmation.
  bool get isConfirmed => this == AppointmentStatus.confirmed;

  bool get isOpen =>
      this == AppointmentStatus.requested ||
      this == AppointmentStatus.inReview ||
      this == AppointmentStatus.rescheduled;
}

/// One appointment owned by the current user.
///
/// Times are stored as UTC instants; [ianaZoneId] is the zone the user picked
/// the civil time in (null = device zone). Display always shows device-local
/// and UTC so no ambiguous local time is ever implied.
class InterviewAppointment {
  const InterviewAppointment({
    required this.id,
    required this.kind,
    required this.title,
    required this.startUtc,
    required this.status,
    this.endUtc,
    this.ianaZoneId,
    this.notes = '',
    required this.createdAt,
    this.backendManaged = true,
  });

  final String id;
  final AppointmentKind kind;
  final String title;
  final String notes;
  final DateTime startUtc;
  final DateTime? endUtc;

  /// Zone the civil time was entered in; null = device zone.
  final String? ianaZoneId;

  final AppointmentStatus status;
  final DateTime createdAt;

  /// True when the row came from a real Backend response.
  final bool backendManaged;

  InterviewAppointment copyWith({
    AppointmentStatus? status,
    DateTime? endUtc,
    String? notes,
  }) {
    return InterviewAppointment(
      id: id,
      kind: kind,
      title: title,
      startUtc: startUtc,
      endUtc: endUtc ?? this.endUtc,
      ianaZoneId: ianaZoneId,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
      backendManaged: backendManaged,
    );
  }

  factory InterviewAppointment.fromJson(Map<String, dynamic> json) {
    return InterviewAppointment(
      id: json['id'] as String? ?? '',
      kind: AppointmentKindX.fromString(json['kind'] as String?),
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      startUtc:
          DateTime.tryParse(json['startUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endUtc: json['endUtc'] != null
          ? DateTime.tryParse(json['endUtc'] as String)
          : null,
      ianaZoneId: json['ianaZoneId'] as String?,
      status: AppointmentStatusX.fromString(json['status'] as String?),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      backendManaged: json['backendManaged'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'notes': notes,
    'startUtc': startUtc.toUtc().toIso8601String(),
    'endUtc': endUtc?.toUtc().toIso8601String(),
    'ianaZoneId': ianaZoneId,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'backendManaged': backendManaged,
  };
}

/// A request the user wants to submit.
class AppointmentRequest {
  const AppointmentRequest({
    required this.title,
    required this.startLocal,
    this.endLocal,
    this.ianaZoneId,
    this.notes = '',
  });

  final String title;

  /// Civil time as entered (device-local [DateTime] semantics; the zone the
  /// user picked is [ianaZoneId] or device when null).
  final DateTime startLocal;
  final DateTime? endLocal;
  final String? ianaZoneId;
  final String notes;
}

/// Explicit capability state for appointment backend operations.
enum AppointmentCapability { available, backendUnavailable, unknown }

class AppointmentListResult {
  const AppointmentListResult({
    required this.appointments,
    required this.capability,
  });

  final List<InterviewAppointment> appointments;
  final AppointmentCapability capability;

  bool get isEmpty => appointments.isEmpty;
}
