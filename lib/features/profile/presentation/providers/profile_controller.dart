import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/dependencies.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/datasources/profile_local_datasource.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final _sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final prefs = ref.watch(_sharedPreferencesProvider).valueOrNull;
  if (prefs == null) {
    return _UnreadyProfileRepository();
  }
  final config = ref.watch(appConfigProvider);
  return ProfileRepositoryImpl(
    remote: ProfileRemoteDataSource(ref.watch(apiClientProvider)),
    local: ProfileLocalDataSource(prefs),
    allowOfflineFallback: !config.environment.isProduction,
  );
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<UserProfile?>>((ref) {
  final session = ref.watch(authControllerProvider).valueOrNull;
  return ProfileController(
    ref.watch(profileRepositoryProvider),
    session,
  );
});

class ProfileController extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileController(this._repository, this._session)
      : super(const AsyncValue.loading()) {
    load();
  }

  final ProfileRepository _repository;
  final UserSession? _session;

  Future<void> load() async {
    final userId = _session?.userId ?? 'user-demo-001';
    state = const AsyncValue.loading();
    try {
      var profile = await _repository.getProfile(userId);
      if (profile == null && _session != null) {
        final fullName = _session!.fullName;
        final parts = (fullName ?? '').split(' ').where((s) => s.isNotEmpty).toList();
        profile = UserProfile(
          id: userId,
          firstName: parts.isNotEmpty ? parts.first : null,
          lastName: parts.length > 1 ? parts.sublist(1).join(' ') : null,
          email: _session.email,
          phone: _session.phone,
        );
      }
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(UserProfile profile) async {
    state = const AsyncValue.loading();
    try {
      final saved = await _repository.updateProfile(profile);
      state = AsyncValue.data(saved);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

class _UnreadyProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile?> getProfile(String userId) async => null;

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async => profile;
}
