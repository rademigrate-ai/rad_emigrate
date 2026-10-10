import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/documents/data/datasources/document_local_datasource.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document.dart';
import 'package:rad_emigrate/features/documents/domain/entities/document_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

Document _document(String id, String userId, {String? signedUrl}) => Document(
  id: id,
  typeId: 'passport',
  name: '$id.pdf',
  status: DocumentVerificationStatus.uploaded,
  kind: DocumentTypeKind.passport,
  userId: userId,
  storagePath: '$userId/$id/$id.pdf',
  fileUrl: signedUrl,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('two accounts cannot read each other document cache', () async {
    final prefs = await SharedPreferences.getInstance();
    final userA = DocumentLocalDataSource(prefs, userId: 'user-a');
    final userB = DocumentLocalDataSource(prefs, userId: 'user-b');

    await userA.writeAll([_document('a-document', 'user-a')]);
    await userB.writeAll([_document('b-document', 'user-b')]);

    expect((await userA.readAll()).map((item) => item.id), ['a-document']);
    expect((await userB.readAll()).map((item) => item.id), ['b-document']);
  });

  test('legacy shared cache is deleted and never migrated', () async {
    SharedPreferences.setMockInitialValues({
      'rad_documents': '[{"id":"other-user-document"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final cache = DocumentLocalDataSource(prefs, userId: 'user-a');

    expect(await cache.readAll(), isEmpty);
    expect(prefs.containsKey('rad_documents'), isFalse);
  });

  test('foreign rows and signed bearer URLs are not persisted', () async {
    final prefs = await SharedPreferences.getInstance();
    final cache = DocumentLocalDataSource(prefs, userId: 'user-a');

    await cache.writeAll([
      _document(
        'owned',
        'user-a',
        signedUrl: 'https://storage.example/signed?token=secret',
      ),
      _document('foreign', 'user-b'),
    ]);

    final restored = await cache.readAll();
    expect(restored, hasLength(1));
    expect(restored.single.id, 'owned');
    expect(restored.single.fileUrl, isNull);
    expect(restored.single.storagePath, 'user-a/owned/owned.pdf');
  });

  test('logout lifecycle clear removes only the departing user', () async {
    final prefs = await SharedPreferences.getInstance();
    final userA = DocumentLocalDataSource(prefs, userId: 'user-a');
    final userB = DocumentLocalDataSource(prefs, userId: 'user-b');
    await userA.writeAll([_document('a-document', 'user-a')]);
    await userB.writeAll([_document('b-document', 'user-b')]);

    await userA.clear();

    expect(await userA.readAll(), isEmpty);
    expect((await userB.readAll()).single.id, 'b-document');
  });
}
