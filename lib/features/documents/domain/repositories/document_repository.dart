import 'dart:typed_data';

import '../entities/document.dart';

abstract class DocumentRepository {
  Future<List<Document>> listDocuments({String? userId});
  Future<Document?> getDocument(String id);
  Future<Document> upsertDocument(Document document);
  Future<Document> uploadDocument({
    required Document document,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  });
}
