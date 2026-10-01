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

  Future<List<Document>> _ensureLocal() async {
    return local.readAll();
  }

  @override
  Future<List<Document>> listDocuments({String? userId}) async {
    try {
      final remoteList = await remote.list(userId: userId);
      await local.writeAll(remoteList);
      return remoteList;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      return _ensureLocal();
    }
  }

  @override
  Future<Document?> getDocument(String id) async {
    final all = await listDocuments();
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<Document> upsertDocument(Document document) async {
    try {
      final saved = await remote.upsert(document);
      final cached = await local.readAll();
      final idx = cached.indexWhere((d) => d.id == saved.id);
      if (idx >= 0) {
        cached[idx] = saved;
      } else {
        cached.add(saved);
      }
      await local.writeAll(cached);
      return saved;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final cached = await _ensureLocal();
      final saved = document.copyWith(updatedAt: DateTime.now());
      final idx = cached.indexWhere((d) => d.id == saved.id);
      if (idx >= 0) {
        cached[idx] = saved;
      } else {
        cached.add(saved);
      }
      await local.writeAll(cached);
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
    final uploaded = await remote.upload(
      document: document,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    final cached = await local.readAll();
    final index = cached.indexWhere((item) => item.id == uploaded.id);
    if (index >= 0) {
      cached[index] = uploaded;
    } else {
      cached.add(uploaded);
    }
    await local.writeAll(cached);
    return uploaded;
  }

  @override
  Future<void> deleteDocument(Document document) async {
    await remote.delete(document);
    final cached = await local.readAll();
    cached.removeWhere((item) => item.id == document.id);
    await local.writeAll(cached);
  }
}
