import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class SupabaseStorageService {
  SupabaseStorageService(this._service);

  final SupabaseClientService _service;
  static const bucket = 'documents';

  Future<String> upload({
    required String userId,
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final path = '$userId/$documentId/$fileName';
    await _service.client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  Future<String> createSignedUrl(String path, {int expiresIn = 3600}) {
    return _service.client.storage
        .from(bucket)
        .createSignedUrl(path, expiresIn);
  }

  Future<void> delete(String path) {
    return _service.client.storage.from(bucket).remove([path]).then((_) {});
  }
}
