/// Supported immigration document categories.
enum DocumentTypeKind {
  passport,
  identity,
  education,
  financial,
  visa,
  other,
}

extension DocumentTypeKindX on DocumentTypeKind {
  String get label {
    switch (this) {
      case DocumentTypeKind.passport:
        return 'Passport';
      case DocumentTypeKind.identity:
        return 'Identity';
      case DocumentTypeKind.education:
        return 'Education';
      case DocumentTypeKind.financial:
        return 'Financial';
      case DocumentTypeKind.visa:
        return 'Visa';
      case DocumentTypeKind.other:
        return 'Other';
    }
  }

  static DocumentTypeKind fromString(String value) {
    return DocumentTypeKind.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DocumentTypeKind.other,
    );
  }
}

class DocumentType {
  const DocumentType({
    required this.id,
    required this.kind,
    required this.name,
    this.description,
  });

  final String id;
  final DocumentTypeKind kind;
  final String name;
  final String? description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'description': description,
      };

  factory DocumentType.fromJson(Map<String, dynamic> json) {
    return DocumentType(
      id: json['id'] as String? ?? '',
      kind: DocumentTypeKindX.fromString(json['kind'] as String? ?? 'other'),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}
