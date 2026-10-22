import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/datasources/document_local_datasource.dart';
import '../../data/datasources/document_remote_datasource.dart';
import '../../data/repositories/document_repository_impl.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/document_type.dart';
import '../../domain/repositories/document_repository.dart';

final _prefsProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final prefs = ref.watch(_prefsProvider).valueOrNull;
  if (prefs == null) return _EmptyDocumentRepository();
  final config = ref.watch(appConfigProvider);
  return DocumentRepositoryImpl(
    remote: DocumentRemoteDataSource(
      ref.watch(supabaseClientServiceProvider),
      storage: ref.watch(supabaseStorageServiceProvider),
    ),
    local: DocumentLocalDataSource(prefs),
    allowOfflineFallback: !config.isProduction,
  );
});

final documentControllerProvider =
    StateNotifierProvider<DocumentController, AsyncValue<List<Document>>>((
      ref,
    ) {
      final userId = ref.watch(authenticatedUserIdProvider);
      return DocumentController(
        ref.watch(documentRepositoryProvider),
        userId,
        isCurrent: () => ref.read(authenticatedUserIdProvider) == userId,
      );
    });

class DocumentController extends StateNotifier<AsyncValue<List<Document>>> {
  DocumentController(
    this._repository,
    this._userId, {
    bool Function()? isCurrent,
  }) : _isCurrent = isCurrent ?? (() => true),
       super(const AsyncValue.loading()) {
    load();
  }

  final DocumentRepository _repository;
  final String? _userId;
  final bool Function() _isCurrent;
  bool get _active => mounted && _isCurrent();
  void _requireActive() {
    if (!_active || _userId == null || _userId.isEmpty) {
      throw StateError("Private session changed");
    }
  }

  Future<void> load() async {
    if (!_active) return;
    if (_userId == null || _userId.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final items = await _repository.listDocuments(userId: _userId);
      if (!_active) return;
      state = AsyncValue.data(
        items.where((item) => item.userId == _userId).toList(),
      );
    } catch (e, st) {
      if (!_active) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> uploadFile(
    String id, {
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    _requireActive();
    final current = state.valueOrNull ?? [];
    Document? doc;
    for (final d in current) {
      if (d.id == id) {
        doc = d;
        break;
      }
    }
    if (doc == null || doc.userId != _userId) return;
    final updated = await _repository.uploadDocument(
      document: doc,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    _requireActive();
    state = AsyncValue.data(
      current.map((d) => d.id == id ? updated : d).toList(),
    );
  }

  Future<Uri> previewDocument(String id) async {
    _requireActive();
    if (_userId == null || _userId.isEmpty) {
      throw StateError('Authentication required for a private file preview.');
    }
    final current = state.valueOrNull ?? [];
    for (final document in current) {
      if (document.id == id && document.userId == _userId) {
        final uri = await _repository.previewDocument(document);
        _requireActive();
        return uri;
      }
    }
    throw StateError('Document not found for the active user.');
  }

  Future<void> deleteDocument(String id) async {
    _requireActive();
    final current = state.valueOrNull ?? [];
    Document? document;
    for (final item in current) {
      if (item.id == id) {
        document = item;
        break;
      }
    }
    if (document == null || document.userId != _userId) return;
    await _repository.deleteDocument(document);
    _requireActive();
    state = AsyncValue.data(current.where((item) => item.id != id).toList());
  }

  Future<void> addDocumentType({
    required String name,
    required DocumentTypeKind kind,
  }) async {
    _requireActive();
    final created = await _repository.upsertDocument(
      Document(
        id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
        typeId: kind.name,
        name: name,
        status: DocumentVerificationStatus.missing,
        kind: kind,
        userId: _userId,
        updatedAt: DateTime.now(),
      ),
    );
    _requireActive();
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([created, ...current]);
  }
}

class _EmptyDocumentRepository implements DocumentRepository {
  @override
  Future<List<Document>> listDocuments({String? userId}) async => [];

  @override
  Future<Document?> getDocument(String id) async => null;

  @override
  Future<Document> upsertDocument(Document document) async => document;

  @override
  Future<void> deleteDocument(Document document) async {}

  @override
  Future<Uri> previewDocument(Document document) async =>
      throw StateError('Private document preview is not configured.');

  @override
  Future<Document> uploadDocument({
    required Document document,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async => throw StateError('Document repository is not ready.');
}
