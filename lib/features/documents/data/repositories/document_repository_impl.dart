import '../../../../core/network/api_exception.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/document_type.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/document_local_datasource.dart';
import '../datasources/document_remote_datasource.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl({
    required DocumentRemoteDataSource remote,
    required DocumentLocalDataSource local,
    this.allowOfflineFallback = true,
  })  : _remote = remote,
        _local = local;

  final DocumentRemoteDataSource _remote;
  final DocumentLocalDataSource _local;
  final bool allowOfflineFallback;

  static final _seed = [
    Document(
      id: 'doc-1',
      typeId: 'passport',
      name: 'Passport',
      status: DocumentVerificationStatus.verified,
      kind: DocumentTypeKind.passport,
      updatedAt: DateTime(2026, 9, 10),
      userId: 'user-demo-001',
    ),
    Document(
      id: 'doc-2',
      typeId: 'photo',
      name: 'Photograph',
      status: DocumentVerificationStatus.uploaded,
      kind: DocumentTypeKind.identity,
      updatedAt: DateTime(2026, 9, 18),
      userId: 'user-demo-001',
    ),
    Document(
      id: 'doc-3',
      typeId: 'education',
      name: 'Bachelor Degree',
      status: DocumentVerificationStatus.underReview,
      kind: DocumentTypeKind.education,
      updatedAt: DateTime(2026, 9, 22),
      userId: 'user-demo-001',
    ),
    Document(
      id: 'doc-4',
      typeId: 'language',
      name: 'IELTS Result',
      status: DocumentVerificationStatus.missing,
      kind: DocumentTypeKind.education,
      userId: 'user-demo-001',
    ),
    Document(
      id: 'doc-5',
      typeId: 'funds',
      name: 'Bank Statement',
      status: DocumentVerificationStatus.missing,
      kind: DocumentTypeKind.financial,
      userId: 'user-demo-001',
    ),
  ];

  Future<List<Document>> _ensureLocal() async {
    var items = await _local.readAll();
    if (items.isEmpty) {
      items = List.of(_seed);
      await _local.writeAll(items);
    }
    return items;
  }

  @override
  Future<List<Document>> listDocuments({String? userId}) async {
    try {
      final remote = await _remote.list(userId: userId);
      await _local.writeAll(remote);
      return remote;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      return _ensureLocal();
    }
  }

  @override
  Future<Document?> getDocument(String id) async {
    final all = await listDocuments();
    try {
      return all.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Document> upsertDocument(Document document) async {
    try {
      final saved = await _remote.upsert(document);
      final local = await _local.readAll();
      final idx = local.indexWhere((d) => d.id == saved.id);
      if (idx >= 0) {
        local[idx] = saved;
      } else {
        local.add(saved);
      }
      await _local.writeAll(local);
      return saved;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final local = await _ensureLocal();
      final saved = document.copyWith(updatedAt: DateTime.now());
      final idx = local.indexWhere((d) => d.id == saved.id);
      if (idx >= 0) {
        local[idx] = saved;
      } else {
        local.add(saved);
      }
      await _local.writeAll(local);
      return saved;
    }
  }
}
