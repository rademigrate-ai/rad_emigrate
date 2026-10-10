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
    required this.userId,
    this.allowOfflineFallback = true,
  });

  final DocumentRemoteDataSource remote;
  final DocumentLocalDataSource local;
  final String userId;
  final bool allowOfflineFallback;

  Future<List<Document>> _ensureLocal() async {
    return local.readAll();
  }

  @override
  Future<List<Document>> listDocuments({String? userId}) async {
    if (userId != null && userId != this.userId) {
      throw const ApiException(
        message: 'A document cache cannot be read for another account.',
        code: 'document_owner_mismatch',
      );
    }
    try {
      final remoteList = await remote.list(userId: this.userId);
      if (remoteList.any((document) => document.userId != this.userId)) {
        throw const ApiException(
          message: 'The document response contained another account.',
          code: 'document_owner_mismatch',
        );
      }
      await local.writeAll(remoteList);
      return remoteList;
    } on ApiException catch (error) {
      if (!allowOfflineFallback || error.code == 'document_owner_mismatch') {
        rethrow;
      }
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
    final ownedDocument = _forCurrentUser(document);
    try {
      final saved = _requireOwned(await remote.upsert(ownedDocument));
      final cached = await local.readAll();
      final idx = cached.indexWhere((d) => d.id == saved.id);
      if (idx >= 0) {
        cached[idx] = saved;
      } else {
        cached.add(saved);
      }
      await local.writeAll(cached);
      return saved;
    } on ApiException catch (error) {
      if (!allowOfflineFallback || error.code == 'document_owner_mismatch') {
        rethrow;
      }
      final cached = await _ensureLocal();
      final saved = ownedDocument.copyWith(updatedAt: DateTime.now());
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
    final uploaded = _requireOwned(
      await remote.upload(
        document: _forCurrentUser(document),
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      ),
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
    final ownedDocument = _forCurrentUser(document);
    await remote.delete(ownedDocument);
    final cached = await local.readAll();
    cached.removeWhere((item) => item.id == document.id);
    await local.writeAll(cached);
  }

  Document _forCurrentUser(Document document) {
    if (document.userId != null && document.userId != userId) {
      throw const ApiException(
        message: 'A document cannot be changed by another account.',
        code: 'document_owner_mismatch',
      );
    }
    return document.userId == userId
        ? document
        : document.copyWith(userId: userId);
  }

  Document _requireOwned(Document document) {
    if (document.userId != userId) {
      throw const ApiException(
        message: 'The document response contained another account.',
        code: 'document_owner_mismatch',
      );
    }
    return document;
  }
}
