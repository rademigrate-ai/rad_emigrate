import 'dart:async';
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
  final userId = ref.watch(
    authControllerProvider.select((state) => state.valueOrNull?.userId),
  );
  if (prefs == null || userId == null || userId.isEmpty) {
    return _EmptyDocumentRepository();
  }
  final config = ref.watch(appConfigProvider);
  return DocumentRepositoryImpl(
    remote: DocumentRemoteDataSource(
      ref.watch(supabaseClientServiceProvider),
      storage: ref.watch(supabaseStorageServiceProvider),
    ),
    local: DocumentLocalDataSource(prefs, userId: userId),
    userId: userId,
    allowOfflineFallback: !config.isProduction,
  );
});

/// Removes the departing account's cache on logout or account switch.
final documentCacheLifecycleProvider = Provider<void>((ref) {
  ref.listen<String?>(
    authControllerProvider.select((state) => state.valueOrNull?.userId),
    (previousUserId, nextUserId) {
      if (previousUserId == null || previousUserId == nextUserId) return;
      unawaited(
        SharedPreferences.getInstance().then(
          (prefs) =>
              DocumentLocalDataSource(prefs, userId: previousUserId).clear(),
        ),
      );
    },
  );
});

final documentControllerProvider =
    StateNotifierProvider<DocumentController, AsyncValue<List<Document>>>((
      ref,
    ) {
      ref.watch(documentCacheLifecycleProvider);
      final userId = ref.watch(authControllerProvider).valueOrNull?.userId;
      return DocumentController(ref.watch(documentRepositoryProvider), userId);
    });

class DocumentController extends StateNotifier<AsyncValue<List<Document>>> {
  DocumentController(this._repository, this._userId)
    : super(const AsyncValue.loading()) {
    load();
  }

  final DocumentRepository _repository;
  final String? _userId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.listDocuments(userId: _userId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> uploadFile(
    String id, {
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final current = state.valueOrNull ?? [];
    Document? doc;
    for (final d in current) {
      if (d.id == id) {
        doc = d;
        break;
      }
    }
    if (doc == null) return;
    final updated = await _repository.uploadDocument(
      document: doc,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    state = AsyncValue.data(
      current.map((d) => d.id == id ? updated : d).toList(),
    );
  }

  Future<void> deleteDocument(String id) async {
    final current = state.valueOrNull ?? [];
    Document? document;
    for (final item in current) {
      if (item.id == id) {
        document = item;
        break;
      }
    }
    if (document == null) return;
    await _repository.deleteDocument(document);
    state = AsyncValue.data(current.where((item) => item.id != id).toList());
  }

  Future<void> addDocumentType({
    required String name,
    required DocumentTypeKind kind,
  }) async {
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
  Future<Document> uploadDocument({
    required Document document,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async => throw StateError('Document repository is not ready.');
}
