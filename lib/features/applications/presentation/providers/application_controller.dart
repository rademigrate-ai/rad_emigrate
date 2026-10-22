import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/datasources/application_local_datasource.dart';
import '../../data/datasources/application_remote_datasource.dart';
import '../../data/repositories/application_repository_impl.dart';
import '../../domain/entities/application_status.dart';
import '../../domain/entities/visa_application.dart';
import '../../domain/repositories/application_repository.dart';

final _prefsProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// Real repository once SharedPreferences is ready; otherwise null so the
/// controller stays in loading instead of permanently binding an empty repo.
final applicationRepositoryProvider = Provider<ApplicationRepository?>((ref) {
  // Re-subscribe so the provider rebuilds when prefs complete.
  final prefsAsync = ref.watch(_prefsProvider);
  final prefs = prefsAsync.valueOrNull;
  if (prefs == null) return null;
  final config = ref.watch(appConfigProvider);
  return ApplicationRepositoryImpl(
    remote: ApplicationRemoteDataSource(
      ref.watch(supabaseClientServiceProvider),
    ),
    local: ApplicationLocalDataSource(prefs),
    allowOfflineFallback: !config.isProduction,
  );
});

final applicationControllerProvider =
    StateNotifierProvider<
      ApplicationController,
      AsyncValue<List<VisaApplication>>
    >((ref) {
      final userId = ref.watch(authenticatedUserIdProvider);
      final repository = ref.watch(applicationRepositoryProvider);
      return ApplicationController(
        repository,
        userId,
        isCurrent: () => ref.read(authenticatedUserIdProvider) == userId,
      );
    });

class ApplicationController
    extends StateNotifier<AsyncValue<List<VisaApplication>>> {
  ApplicationController(
    this._repository,
    this._userId, {
    bool Function()? isCurrent,
  }) : _isCurrent = isCurrent ?? (() => true),
       super(const AsyncValue.loading()) {
    load();
  }

  final ApplicationRepository? _repository;
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
    final repository = _repository;
    if (repository == null) {
      state = const AsyncValue.loading();
      return;
    }
    if (_userId == null || _userId.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final items = await repository.listApplications(userId: _userId);
      if (!_active) return;
      state = AsyncValue.data(
        items.where((item) => item.userId == _userId).toList(),
      );
    } catch (e, st) {
      if (!_active) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStatus(String id, ApplicationStatus status) async {
    _requireActive();
    final repository = _repository;
    if (repository == null) return;
    final current = state.valueOrNull ?? [];
    VisaApplication? app;
    for (final a in current) {
      if (a.id == id) {
        app = a;
        break;
      }
    }
    if (app == null || app.userId != _userId) return;
    final updated = await repository.updateApplication(
      app.copyWith(status: status),
    );
    if (!_active) return;
    final next = current.map((a) => a.id == id ? updated : a).toList();
    state = AsyncValue.data(next);
  }

  Future<VisaApplication> createDraft({
    required String title,
    required String programName,
    required String country,
  }) async {
    _requireActive();
    final repository = _repository;
    if (repository == null) {
      throw StateError('Application repository is not ready yet.');
    }
    final created = await repository.createApplication(
      VisaApplication(
        id: 'temp',
        title: title,
        programName: programName,
        country: country,
        status: ApplicationStatus.draft,
        updatedAt: DateTime.now(),
        userId: _userId,
        createdAt: DateTime.now(),
      ),
    );
    _requireActive();
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([created, ...current]);
    return created;
  }
}
