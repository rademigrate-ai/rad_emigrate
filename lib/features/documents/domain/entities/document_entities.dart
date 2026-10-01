enum DocumentStatus { missing, uploaded, underReview, verified, rejected }

extension DocumentStatusX on DocumentStatus {
  String get label {
    switch (this) {
      case DocumentStatus.missing:
        return 'Missing';
      case DocumentStatus.uploaded:
        return 'Uploaded';
      case DocumentStatus.underReview:
        return 'Under Review';
      case DocumentStatus.verified:
        return 'Verified';
      case DocumentStatus.rejected:
        return 'Rejected';
    }
  }
}

class DocumentType {
  final String id;
  final String name;
  final String description;

  const DocumentType({
    required this.id,
    required this.name,
    required this.description,
  });
}

class DocumentItem {
  final String id;
  final String typeId;
  final String name;
  final DocumentStatus status;
  final DateTime? updatedAt;

  const DocumentItem({
    required this.id,
    required this.typeId,
    required this.name,
    required this.status,
    this.updatedAt,
  });
}
