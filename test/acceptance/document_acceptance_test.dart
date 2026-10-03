import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document_type.dart';

void main() {
  group('Document acceptance', () {
    test('storagePath and ownership fields persist through serialization', () {
      final doc = Document(
        id: 'doc-1',
        typeId: 'passport',
        name: 'passport.pdf',
        status: DocumentVerificationStatus.uploaded,
        kind: DocumentTypeKind.passport,
        userId: 'user-a',
        storagePath: 'user-a/doc-1/passport.pdf',
        mimeType: 'application/pdf',
        fileUrl: null, // signed URL must not be required for ownership
      );
      final restored = Document.fromJson(doc.toJson());
      expect(restored.userId, 'user-a');
      expect(restored.storagePath, 'user-a/doc-1/passport.pdf');
      expect(restored.mimeType, 'application/pdf');
      expect(restored.fileUrl, isNull);
    });

    test('signed URL is optional and not used as deletion identity', () {
      final withSigned = Document(
        id: 'doc-2',
        typeId: 'financial',
        name: 'bank.pdf',
        status: DocumentVerificationStatus.uploaded,
        kind: DocumentTypeKind.financial,
        userId: 'user-a',
        storagePath: 'user-a/doc-2/bank.pdf',
        fileUrl: 'https://signed.example/temporary?token=abc',
      );
      // Identity for delete/update is id + storagePath + userId, not fileUrl.
      expect(withSigned.id, isNotEmpty);
      expect(withSigned.storagePath, isNotEmpty);
      expect(withSigned.fileUrl, isNot(equals(withSigned.storagePath)));
    });

    test('verification status labels cover lifecycle', () {
      for (final status in DocumentVerificationStatus.values) {
        expect(status.label, isNotEmpty);
      }
      expect(
        DocumentVerificationStatusX.fromString('bogus'),
        DocumentVerificationStatus.missing,
      );
    });

    test('document type kinds are stable for UI filters', () {
      expect(DocumentTypeKind.passport.label, 'Passport');
      expect(
        DocumentTypeKindX.fromString('unknown_kind'),
        DocumentTypeKind.other,
      );
    });
  });
}
