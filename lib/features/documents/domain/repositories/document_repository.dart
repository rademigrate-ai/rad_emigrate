import '../entities/document.dart';

abstract class DocumentRepository {
  Future<List<Document>> listDocuments({String? userId});
  Future<Document?> getDocument(String id);
  Future<Document> upsertDocument(Document document);
}
