import 'document_type.dart';

enum DocumentVerificationStatus {
  missing,
  uploaded,
  underReview,
  verified,
  rejected,
}

extension DocumentVerificationStatusX on DocumentVerificationStatus {
  String get label {
    switch (this) {
      case DocumentVerificationStatus.missing:
        return 'Missing';
      case DocumentVerificationStatus.uploaded:
        return 'Uploaded';
      case DocumentVerificationStatus.underReview:
        return 'Under Review';
      case DocumentVerificationStatus.verified:
        return 'Verified';
      case DocumentVerificationStatus.rejected:
        return 'Rejected';
    }
  }

  static DocumentVerificationStatus fromString(String value) {
    return DocumentVerificationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DocumentVerificationStatus.missing,
    );
  }
}

/// Immutable document domain model.
/// Prepared for future upload, OCR, verification, and AI analysis.
class Document {
  const Document({
    required this.id,
    required this.typeId,
    required this.name,
    required this.status,
    this.kind = DocumentTypeKind.other,
    this.userId,
    this.fileUrl,
    this.mimeType,
    this.updatedAt,
    this.ocrText,
    this.aiSummary,
  });

  final String id;
  final String typeId;
  final String name;
  final DocumentVerificationStatus status;
  final DocumentTypeKind kind;
  final String? userId;
  final String? fileUrl;
  final String? mimeType;
  final DateTime? updatedAt;
  final String? ocrText;
  final String? aiSummary;

  Document copyWith({
    String? id,
    String? typeId,
    String? name,
    DocumentVerificationStatus? status,
    DocumentTypeKind? kind,
    String? userId,
    String? fileUrl,
    String? mimeType,
    DateTime? updatedAt,
    String? ocrText,
    String? aiSummary,
  }) {
    return Document(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      name: name ?? this.name,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      userId: userId ?? this.userId,
      fileUrl: fileUrl ?? this.fileUrl,
      mimeType: mimeType ?? this.mimeType,
      updatedAt: updatedAt ?? this.updatedAt,
      ocrText: ocrText ?? this.ocrText,
      aiSummary: aiSummary ?? this.aiSummary,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'typeId': typeId,
    'name': name,
    'status': status.name,
    'kind': kind.name,
    'userId': userId,
    'fileUrl': fileUrl,
    'mimeType': mimeType,
    'updatedAt': updatedAt?.toIso8601String(),
    'ocrText': ocrText,
    'aiSummary': aiSummary,
  };

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String? ?? '',
      typeId: json['typeId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: DocumentVerificationStatusX.fromString(
        json['status'] as String? ?? 'missing',
      ),
      kind: DocumentTypeKindX.fromString(json['kind'] as String? ?? 'other'),
      userId: json['userId'] as String?,
      fileUrl: json['fileUrl'] as String?,
      mimeType: json['mimeType'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      ocrText: json['ocrText'] as String?,
      aiSummary: json['aiSummary'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Document && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
