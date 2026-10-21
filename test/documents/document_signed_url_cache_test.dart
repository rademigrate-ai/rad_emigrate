import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rad_emigrate/features/documents/data/datasources/document_local_datasource.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testDoc = Document(
    id: 'doc-one',
    typeId: 'passport',
    name: 'passport.pdf',
    status: DocumentVerificationStatus.uploaded,
    userId: 'user-one',
    storagePath: 'user-one/doc-one/passport.pdf',
    fileUrl: 'https://storage.example/private?token=SHOULD_NEVER_BE_CACHED',
  );

  test(
    'new private-document cache writes never contain signed tokens',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = DocumentLocalDataSource(preferences);
      await cache.writeAll([testDoc], userId: 'user-one');

      final stored = preferences.getString(
        DocumentLocalDataSource.keyFor('user-one'),
      );
      expect(stored, isNotNull);
      expect(stored, isNot(contains('SHOULD_NEVER_BE_CACHED')));
      final restored = await cache.readAll(userId: 'user-one');
      expect(restored.single.storagePath, testDoc.storagePath);
      expect(restored.single.fileUrl, isNull);
    },
  );

  test('reading scoped cached signed URLs sanitizes persistent data', () async {
    SharedPreferences.setMockInitialValues({
      DocumentLocalDataSource.keyFor('user-one'): jsonEncode([
        testDoc.toJson(),
      ]),
    });
    final preferences = await SharedPreferences.getInstance();
    final cache = DocumentLocalDataSource(preferences);
    final restored = await cache.readAll(userId: 'user-one');
    expect(restored, hasLength(1));
    expect(restored.single.fileUrl, isNull);
    expect(restored.single.storagePath, testDoc.storagePath);
    final stored = preferences.getString(
      DocumentLocalDataSource.keyFor('user-one'),
    );
    expect(stored, isNot(contains('SHOULD_NEVER_BE_CACHED')));
  });
}
