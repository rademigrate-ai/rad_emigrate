import '../../../../core/network/api_exception.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/document_type.dart';
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

  static final List<Document> _seed = [
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
    var items = await local.readAll();
    if (items.isEmpty) {
      items = List.of(_seed);
      await local.writeAll(items);
    }
    return items;
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
}
