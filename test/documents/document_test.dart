import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document_type.dart';

void main() {
  group('Document', () {
    test('serialization round-trip', () {
      final doc = Document(
        id: 'd1',
        typeId: 'passport',
        name: 'Passport',
        status: DocumentVerificationStatus.verified,
        kind: DocumentTypeKind.passport,
        updatedAt: DateTime.utc(2026, 8, 1),
      );
      final restored = Document.fromJson(doc.toJson());
      expect(restored.id, doc.id);
      expect(restored.status, DocumentVerificationStatus.verified);
      expect(restored.kind, DocumentTypeKind.passport);
      expect(restored, doc);
    });

    test('type labels', () {
      expect(DocumentTypeKind.passport.label, 'Passport');
      expect(DocumentTypeKind.financial.label, 'Financial');
      expect(DocumentVerificationStatus.underReview.label, 'Under Review');
    });
  });
}
