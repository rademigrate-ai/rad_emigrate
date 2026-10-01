import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/document.dart';

class DocumentRemoteDataSource {
  DocumentRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<Document>> list({String? userId}) async {
    final response = await _client.get<List<dynamic>>(
      '/documents',
      queryParameters: userId != null ? {'userId': userId} : null,
    );
    final data = response.data;
    if (data == null) return [];
    return data.map((e) => Document.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Document> upsert(Document document) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/documents/${document.id}',
      data: document.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const ApiException(message: 'Empty document response', code: 'empty_response');
    }
    return Document.fromJson(data);
  }
}
