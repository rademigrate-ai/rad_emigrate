import 'dart:typed_data';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/supabase/supabase_storage.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/document_type.dart';

class DocumentRemoteDataSource {
  DocumentRemoteDataSource(Object backend, {this._storage})
    : _backend = backend;

  final Object _backend;
  final SupabaseStorageService? _storage;

  Future<List<Document>> list({String? userId}) async {
    if (_backend is ApiClient) {
      final response = await (_backend).get<List<dynamic>>(
        '/documents',
        queryParameters: userId != null ? {'userId': userId} : null,
      );
      return (response.data ?? const <dynamic>[])
          .map((e) => Document.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    try {
      var query = _service.client.from('documents').select();
      if (userId != null) query = query.eq('user_id', userId);
      final rows = await query.order('updated_at', ascending: false);
      final docs = <Document>[];
      for (final row in rows as List<dynamic>) {
        docs.add(await _fromRow(row as Map<String, dynamic>));
      }
      return docs;
    } catch (error) {
      throw _toApiException(error);
    }
  }

  Future<Document> upsert(Document document) async {
    if (_backend is ApiClient) {
      final response = await (_backend).put<Map<String, dynamic>>(
        '/documents/${document.id}',
        data: document.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          message: 'Empty document response',
          code: 'empty_response',
        );
      }
      return Document.fromJson(data);
    }
    try {
      final userId = document.userId ?? _service.client.auth.currentUser?.id;
      if (userId == null) {
        throw const ApiException(
          message: 'No authenticated user.',
          code: 'not_authenticated',
        );
      }
      final payload = {
        if (_isUuid(document.id)) 'id': document.id,
        'user_id': userId,
        'name': document.name,
        'status': _statusToDb(document.status),
        'file_path': document.storagePath ?? document.fileUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final row = await _service.client
          .from('documents')
          .upsert(payload)
          .select()
          .single();
      return await _fromRow(row);
    } catch (error) {
      throw _toApiException(error);
    }
  }

  Future<Document> upload({
    required Document document,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (_backend is ApiClient || _storage == null) {
      throw const ApiException(
        message: 'Document storage is not configured.',
        code: 'storage_unavailable',
      );
    }
    try {
      final userId = document.userId ?? _service.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw const ApiException(
          message: 'No authenticated user.',
          code: 'not_authenticated',
        );
      }
      final path = await _storage.upload(
        userId: userId,
        documentId: document.id,
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
      );
      final row = await _service.client
          .from('documents')
          .upsert({
            if (_isUuid(document.id)) 'id': document.id,
            'user_id': userId,
            'name': fileName,
            'status': _statusToDb(DocumentVerificationStatus.uploaded),
            'file_path': path,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return await _fromRow(row);
    } catch (error) {
      throw _toApiException(error);
    }
  }

  Future<void> delete(Document document) async {
    if (_backend is ApiClient) {
      await (_backend).delete<void>('/documents/${document.id}');
      return;
    }
    try {
      final userId = document.userId ?? _service.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw const ApiException(
          message: 'No authenticated user.',
          code: 'not_authenticated',
        );
      }
      final path = document.storagePath;
      if (path != null && path.startsWith('$userId/')) {
        await _storage?.delete(path);
      }
      final deletedRows = await _service.client
          .from('documents')
          .delete()
          .eq('id', document.id)
          .eq('user_id', userId)
          .select('id');
      if (deletedRows.length != 1) {
        throw const ApiException(
          message: 'The document could not be deleted.',
          code: 'document_delete_failed',
        );
      }
    } catch (error) {
      throw _toApiException(error);
    }
  }

  SupabaseClientService get _service => _backend as SupabaseClientService;

  Future<Document> _fromRow(Map<String, dynamic> row) async {
    final path = row['file_path'] as String?;
    String? signedUrl;
    if (path != null && _storage != null) {
      try {
        signedUrl = await _storage.createSignedUrl(path);
      } catch (_) {
        signedUrl = null;
      }
    }
    return Document(
      id: row['id'] as String,
      typeId: row['name'] as String? ?? 'other',
      name: row['name'] as String? ?? 'Document',
      status: _statusFromDb(row['status'] as String? ?? 'missing'),
      kind: DocumentTypeKindX.fromString(row['name'] as String? ?? 'other'),
      userId: row['user_id'] as String?,
      fileUrl: signedUrl,
      storagePath: path,
      updatedAt: DateTime.tryParse(
        row['updated_at']?.toString() ?? row['created_at']?.toString() ?? '',
      ),
    );
  }

  String _statusToDb(DocumentVerificationStatus status) => switch (status) {
    DocumentVerificationStatus.missing => 'missing',
    DocumentVerificationStatus.uploaded => 'uploaded',
    DocumentVerificationStatus.underReview => 'under_review',
    DocumentVerificationStatus.verified => 'verified',
    DocumentVerificationStatus.rejected => 'rejected',
  };

  DocumentVerificationStatus _statusFromDb(String value) => switch (value) {
    'under_review' => DocumentVerificationStatus.underReview,
    _ => DocumentVerificationStatusX.fromString(value),
  };

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

  ApiException _toApiException(Object error) => error is ApiException
      ? error
      : ApiException(
          message: 'Unexpected Supabase error.',
          code: 'supabase_error',
          cause: error,
        );
}
