import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/api_exception.dart';
import 'supabase_client.dart';

class SupabaseStorageService {
  SupabaseStorageService(this._service);

  final SupabaseClientService _service;
  static const bucket = 'documents';
  static const maxBytes = 10 * 1024 * 1024;
  static const allowedContentTypes = {
    'application/pdf',
    'image/jpeg',
    'image/png',
  };

  Future<String> upload({
    required String userId,
    required String documentId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    if (userId.isEmpty || documentId.isEmpty) {
      throw const ApiException(
        message: 'A valid user and document are required.',
        code: 'invalid_storage_path',
      );
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const ApiException(
        message: 'Files must be between 1 byte and 10 MB.',
        code: 'invalid_file_size',
      );
    }
    final resolvedContentType = contentType ?? 'application/octet-stream';
    if (!allowedContentTypes.contains(resolvedContentType)) {
      throw const ApiException(
        message: 'This file type is not supported.',
        code: 'invalid_file_type',
      );
    }
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safeName.isEmpty) {
      throw const ApiException(
        message: 'The selected file has no valid name.',
        code: 'invalid_file_name',
      );
    }
    final path = '$userId/$documentId/$safeName';
    await _service.client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: resolvedContentType,
            upsert: true,
          ),
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
