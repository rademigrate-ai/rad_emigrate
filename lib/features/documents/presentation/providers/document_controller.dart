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

  Future<void> addPlaceholder({
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
  Future<Document> uploadDocument({
    required Document document,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async => throw StateError('Document repository is not ready.');
}
