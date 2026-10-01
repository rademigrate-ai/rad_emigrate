import '../../../../core/network/api_exception.dart';
import '../../domain/entities/application_status.dart';
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

  static final List<VisaApplication> _seed = [
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
    var items = await local.readAll();
    if (items.isEmpty) {
      items = List.of(_seed);
      await local.writeAll(items);
    }
    return items;
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
