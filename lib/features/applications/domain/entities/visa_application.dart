import 'application_status.dart';

/// Immutable visa application domain model.
class VisaApplication {
  const VisaApplication({
    required this.id,
    required this.title,
    required this.programName,
    required this.country,
    required this.status,
    required this.updatedAt,
    this.userId,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String? userId;
  final String title;
  final String programName;
  final String country;
  final ApplicationStatus status;
  final DateTime updatedAt;
  final DateTime? createdAt;
  final String? notes;

  VisaApplication copyWith({
    String? id,
    String? userId,
    String? title,
    String? programName,
    String? country,
    ApplicationStatus? status,
    DateTime? updatedAt,
    DateTime? createdAt,
    String? notes,
  }) {
    return VisaApplication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      programName: programName ?? this.programName,
      country: country ?? this.country,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'programName': programName,
        'country': country,
        'status': status.name,
        'updatedAt': updatedAt.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'notes': notes,
      };

  factory VisaApplication.fromJson(Map<String, dynamic> json) {
    return VisaApplication(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String?,
      title: json['title'] as String? ?? '',
      programName: json['programName'] as String? ?? '',
      country: json['country'] as String? ?? '',
      status: ApplicationStatusX.fromString(json['status'] as String? ?? 'draft'),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisaApplication &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          title == other.title;

  @override
  int get hashCode => Object.hash(id, status, title);
}
