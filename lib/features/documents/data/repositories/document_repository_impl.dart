import 'dart:typed_data';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/document.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/document_local_datasource.dart';
import '../datasources/document_remote_datasource.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl({
    required this.remote,
    required this.local,
    this.allowOfflineFallback = true,
  });

  final DocumentRemoteDataSource remote;
  final DocumentLocalDataSource local;
  final bool allowOfflineFallback;

  Future<List<Document>> _ensureLocal(String userId) async {
    return local.readAll(userId: userId);
  }

  @override
  Future<List<Document>> listDocuments({String? userId}) async {
    if (userId == null || userId.isEmpty) return [];
    try {
      final remoteList = await remote.list(userId: userId);
      await local.writeAll(remoteList, userId: userId);
      return remoteList.where((document) => document.userId == userId).toList();
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      return _ensureLocal(userId);
    }
  }

  @override
  Future<Document?> getDocument(String id) async {
    final all = await listDocuments(userId: remote.currentUserId);
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<Document> upsertDocument(Document document) async {
    final owner = document.userId;
    if (owner == null || owner.isEmpty) {
      throw StateError("Document owner required");
    }
    try {
      final saved = await remote.upsert(document);
      if (saved.userId != owner) {
        throw StateError('Document owner mismatch');
      }
      final cached = await local.readAll(userId: owner);
      final idx = cached.indexWhere((d) => d.id == saved.id);
      if (idx >= 0) {
        cached[idx] = saved;
      } else {
        cached.add(saved);
      }
      await local.writeAll(cached, userId: owner);
      return saved;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final cached = await _ensureLocal(owner);
      final saved = document.copyWith(updatedAt: DateTime.now());
      final idx = cached.indexWhere((d) => d.id == saved.id);
      if (idx >= 0) {
        cached[idx] = saved;
      } else {
        cached.add(saved);
      }
      await local.writeAll(cached, userId: owner);
      return saved;
    }
  }

  @override
  Future<Document> uploadDocument({
    required Document document,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final owner = document.userId;
    if (owner == null || owner.isEmpty) {
      throw StateError("Document owner required");
    }
    final uploaded = await remote.upload(
      document: document,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    if (uploaded.userId != owner) {
      throw StateError('Document owner mismatch');
    }
    final cached = await local.readAll(userId: owner);
    final index = cached.indexWhere((item) => item.id == uploaded.id);
    if (index >= 0) {
      cached[index] = uploaded;
    } else {
      cached.add(uploaded);
    }
    await local.writeAll(cached, userId: owner);
    return uploaded;
  }

  @override
  Future<Uri> previewDocument(Document document) {
    // Preview requires a fresh owner-bound signed URL; no offline fallback.
    return remote.previewDocument(document);
  }

  @override
  Future<void> deleteDocument(Document document) async {
    final owner = document.userId;
    if (owner == null || owner.isEmpty) {
      throw StateError("Document owner required");
    }
    await remote.delete(document);
    final cached = await local.readAll(userId: owner);
    cached.removeWhere((item) => item.id == document.id);
    await local.writeAll(cached, userId: owner);
  }
}
