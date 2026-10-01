import '../../../../core/network/api_exception.dart';
import '../../domain/entities/application_status.dart';
import '../../domain/entities/visa_application.dart';
import '../../domain/repositories/application_repository.dart';
import '../datasources/application_local_datasource.dart';
import '../datasources/application_remote_datasource.dart';

class ApplicationRepositoryImpl implements ApplicationRepository {
  ApplicationRepositoryImpl({
    required ApplicationRemoteDataSource remote,
    required ApplicationLocalDataSource local,
    this.allowOfflineFallback = true,
  })  : _remote = remote,
        _local = local;

  final ApplicationRemoteDataSource _remote;
  final ApplicationLocalDataSource _local;
  final bool allowOfflineFallback;

  static final _seed = [
    VisaApplication(
      id: 'app-001',
      title: 'Study Permit Application',
      programName: 'Canada Study Permit',
      country: 'Canada',
      status: ApplicationStatus.reviewing,
      updatedAt: DateTime(2026, 9, 20),
      notes: 'Documents submitted. Awaiting response.',
      userId: 'user-demo-001',
      createdAt: DateTime(2026, 8, 1),
    ),
    VisaApplication(
      id: 'app-002',
      title: 'Student Visa Draft',
      programName: 'Australia Student Visa (500)',
      country: 'Australia',
      status: ApplicationStatus.draft,
      updatedAt: DateTime(2026, 9, 28),
      notes: 'GTE statement pending.',
      userId: 'user-demo-001',
      createdAt: DateTime(2026, 9, 10),
    ),
    VisaApplication(
      id: 'app-003',
      title: 'Job Seeker',
      programName: 'Germany Job Seeker Visa',
      country: 'Germany',
      status: ApplicationStatus.submitted,
      updatedAt: DateTime(2026, 9, 15),
      userId: 'user-demo-001',
      createdAt: DateTime(2026, 9, 1),
    ),
  ];

  Future<List<VisaApplication>> _ensureLocal() async {
    var items = await _local.readAll();
    if (items.isEmpty) {
      items = List.of(_seed);
      await _local.writeAll(items);
    }
    return items;
  }

  @override
  Future<List<VisaApplication>> listApplications({String? userId}) async {
    try {
      final remote = await _remote.list(userId: userId);
      await _local.writeAll(remote);
      return remote;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final local = await _ensureLocal();
      if (userId == null) return local;
      return local.where((a) => a.userId == userId || a.userId == null).toList();
    }
  }

  @override
  Future<VisaApplication?> getApplication(String id) async {
    try {
      return await _remote.get(id);
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final local = await _ensureLocal();
      try {
        return local.firstWhere((a) => a.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<VisaApplication> createApplication(VisaApplication application) async {
    try {
      final created = await _remote.create(application);
      final local = await _local.readAll();
      local.add(created);
      await _local.writeAll(local);
      return created;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final local = await _ensureLocal();
      final created = application.copyWith(
        id: 'app-${DateTime.now().millisecondsSinceEpoch}',
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      local.add(created);
      await _local.writeAll(local);
      return created;
    }
  }

  @override
  Future<VisaApplication> updateApplication(VisaApplication application) async {
    try {
      final updated = await _remote.update(application);
      final local = await _local.readAll();
      final idx = local.indexWhere((a) => a.id == updated.id);
      if (idx >= 0) {
        local[idx] = updated;
      } else {
        local.add(updated);
      }
      await _local.writeAll(local);
      return updated;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      final local = await _ensureLocal();
      final updated = application.copyWith(updatedAt: DateTime.now());
      final idx = local.indexWhere((a) => a.id == updated.id);
      if (idx >= 0) {
        local[idx] = updated;
      } else {
        local.add(updated);
      }
      await _local.writeAll(local);
      return updated;
    }
  }
}
