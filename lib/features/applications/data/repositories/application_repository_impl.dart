import '../../../../core/network/api_exception.dart';
import '../../domain/entities/visa_application.dart';
import '../../domain/repositories/application_repository.dart';
import '../datasources/application_local_datasource.dart';
import '../datasources/application_remote_datasource.dart';

class ApplicationRepositoryImpl implements ApplicationRepository {
  ApplicationRepositoryImpl({
    required this.remote,
    required this.local,
    this.allowOfflineFallback = true,
  });

  final ApplicationRemoteDataSource remote;
  final ApplicationLocalDataSource local;
  final bool allowOfflineFallback;

  Future<List<VisaApplication>> _ensureLocal() async {
    return local.readAll();
  }

  @override
  Future<List<VisaApplication>> listApplications({String? userId}) async {
    try {
      final remoteList = await remote.list(userId: userId);
      await local.writeAll(remoteList);
      return remoteList;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final cached = await _ensureLocal();
      if (userId == null) return cached;
      return cached
          .where((a) => a.userId == userId || a.userId == null)
          .toList();
    }
  }

  @override
  Future<VisaApplication?> getApplication(String id) async {
    try {
      return await remote.get(id);
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final cached = await _ensureLocal();
      for (final a in cached) {
        if (a.id == id) return a;
      }
      return null;
    }
  }

  @override
  Future<VisaApplication> createApplication(VisaApplication application) async {
    try {
      final created = await remote.create(application);
      final cached = await local.readAll();
      cached.add(created);
      await local.writeAll(cached);
      return created;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final cached = await _ensureLocal();
      final created = application.copyWith(
        id: 'app-${DateTime.now().millisecondsSinceEpoch}',
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      cached.add(created);
      await local.writeAll(cached);
      return created;
    }
  }

  @override
  Future<VisaApplication> updateApplication(VisaApplication application) async {
    try {
      final updated = await remote.update(application);
      final cached = await local.readAll();
      final idx = cached.indexWhere((a) => a.id == updated.id);
      if (idx >= 0) {
        cached[idx] = updated;
      } else {
        cached.add(updated);
      }
      await local.writeAll(cached);
      return updated;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final cached = await _ensureLocal();
      final updated = application.copyWith(updatedAt: DateTime.now());
      final idx = cached.indexWhere((a) => a.id == updated.id);
      if (idx >= 0) {
        cached[idx] = updated;
      } else {
        cached.add(updated);
      }
      await local.writeAll(cached);
      return updated;
    }
  }
}
