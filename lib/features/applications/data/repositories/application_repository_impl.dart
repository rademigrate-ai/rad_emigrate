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

  Future<void> _cacheForUser(
    String? userId,
    List<VisaApplication> items,
  ) async {
    if (userId != null && userId.isNotEmpty) {
      await local.writeForUser(userId, items);
    } else {
      // Fallback only when caller omitted userId (legacy paths).
      await local.writeAll(items);
    }
  }

  Future<List<VisaApplication>> _readCache({String? userId}) async {
    if (userId != null && userId.isNotEmpty) {
      return local.readForUser(userId);
    }
    return local.readAll();
  }

  @override
  Future<List<VisaApplication>> listApplications({String? userId}) async {
    try {
      final remoteList = await remote.list(userId: userId);
      await _cacheForUser(userId, remoteList);
      return remoteList;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final cached = await _readCache(userId: userId);
      if (userId == null || userId.isEmpty) return cached;
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
      // Search scoped caches is not possible without userId; scan legacy only.
      final cached = await local.readAll();
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
      final uid = created.userId;
      if (uid != null && uid.isNotEmpty) {
        final cached = await local.readForUser(uid);
        cached.add(created);
        await local.writeForUser(uid, cached);
      } else {
        final cached = await local.readAll();
        cached.add(created);
        await local.writeAll(cached);
      }
      return created;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final uid = application.userId;
      final created = application.copyWith(
        id: 'app-${DateTime.now().millisecondsSinceEpoch}',
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      if (uid != null && uid.isNotEmpty) {
        final cached = await local.readForUser(uid);
        cached.add(created);
        await local.writeForUser(uid, cached);
      } else {
        final cached = await local.readAll();
        cached.add(created);
        await local.writeAll(cached);
      }
      return created;
    }
  }

  @override
  Future<VisaApplication> updateApplication(VisaApplication application) async {
    try {
      final updated = await remote.update(application);
      final uid = updated.userId;
      if (uid != null && uid.isNotEmpty) {
        final cached = await local.readForUser(uid);
        final idx = cached.indexWhere((a) => a.id == updated.id);
        if (idx >= 0) {
          cached[idx] = updated;
        } else {
          cached.add(updated);
        }
        await local.writeForUser(uid, cached);
      } else {
        final cached = await local.readAll();
        final idx = cached.indexWhere((a) => a.id == updated.id);
        if (idx >= 0) {
          cached[idx] = updated;
        } else {
          cached.add(updated);
        }
        await local.writeAll(cached);
      }
      return updated;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final updated = application.copyWith(updatedAt: DateTime.now());
      final uid = updated.userId;
      if (uid != null && uid.isNotEmpty) {
        final cached = await local.readForUser(uid);
        final idx = cached.indexWhere((a) => a.id == updated.id);
        if (idx >= 0) {
          cached[idx] = updated;
        } else {
          cached.add(updated);
        }
        await local.writeForUser(uid, cached);
      } else {
        final cached = await local.readAll();
        final idx = cached.indexWhere((a) => a.id == updated.id);
        if (idx >= 0) {
          cached[idx] = updated;
        } else {
          cached.add(updated);
        }
        await local.writeAll(cached);
      }
      return updated;
    }
  }
}
