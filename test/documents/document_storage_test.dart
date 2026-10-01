import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document_type.dart';

void main() {
  test('storage path survives local cache serialization', () {
    const document = Document(
      id: 'd1',
      typeId: 'passport',
      name: 'passport.pdf',
      status: DocumentVerificationStatus.uploaded,
      kind: DocumentTypeKind.passport,
      userId: 'user-1',
      fileUrl: 'https://signed.example/file',
      storagePath: 'user-1/d1/passport.pdf',
    );

    final restored = Document.fromJson(document.toJson());

    expect(restored.storagePath, 'user-1/d1/passport.pdf');
    expect(restored.fileUrl, document.fileUrl);
  });
}
