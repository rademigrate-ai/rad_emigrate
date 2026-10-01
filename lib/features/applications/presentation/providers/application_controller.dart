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

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  final prefs = ref.watch(_prefsProvider).valueOrNull;
  if (prefs == null) return _EmptyApplicationRepository();
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
      final userId = ref.watch(authControllerProvider).valueOrNull?.userId;
      return ApplicationController(
        ref.watch(applicationRepositoryProvider),
        userId,
      );
    });

class ApplicationController
    extends StateNotifier<AsyncValue<List<VisaApplication>>> {
  ApplicationController(this._repository, this._userId)
    : super(const AsyncValue.loading()) {
    load();
  }

  final ApplicationRepository _repository;
  final String? _userId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.listApplications(userId: _userId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStatus(String id, ApplicationStatus status) async {
    final current = state.valueOrNull ?? [];
    VisaApplication? app;
    for (final a in current) {
      if (a.id == id) {
        app = a;
        break;
      }
    }
    if (app == null) return;
    final updated = await _repository.updateApplication(
      app.copyWith(status: status),
    );
    final next = current.map((a) => a.id == id ? updated : a).toList();
    state = AsyncValue.data(next);
  }

  Future<VisaApplication> createDraft({
    required String title,
    required String programName,
    required String country,
  }) async {
    final created = await _repository.createApplication(
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
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([created, ...current]);
    return created;
  }
}

class _EmptyApplicationRepository implements ApplicationRepository {
  @override
  Future<List<VisaApplication>> listApplications({String? userId}) async => [];

  @override
  Future<VisaApplication?> getApplication(String id) async => null;

  @override
  Future<VisaApplication> createApplication(
    VisaApplication application,
  ) async => application;

  @override
  Future<VisaApplication> updateApplication(
    VisaApplication application,
  ) async => application;
}
