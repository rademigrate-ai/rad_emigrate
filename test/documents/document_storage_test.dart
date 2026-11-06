import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_storage.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document_type.dart';

import '../support/mock_supabase_service.dart';

void main() {
  test('private uploads request immediate cache revalidation', () async {
    var uploaded = false;
    final service = await mockSupabaseService((request) async {
      uploaded = true;
      expect(request.method, 'POST');
      final cache = RegExp(r'name="cacheControl"\r\n\r\n([^\r\n]+)')
          .firstMatch(request.body);
      expect(cache?.group(1), '0');
      return rpcJson({'Key': 'documents/$testOwner/doc/private.pdf'});
    });
    final path = await SupabaseStorageService(service).upload(
      userId: testOwner,
      documentId: 'doc',
      fileName: 'private.pdf',
      bytes: Uint8List.fromList('%PDF-1.4\n'.codeUnits),
      contentType: 'application/pdf',
    );
    expect(uploaded, isTrue);
    expect(path, '$testOwner/doc/private.pdf');
  });

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
