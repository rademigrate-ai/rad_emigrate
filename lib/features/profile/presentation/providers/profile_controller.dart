import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/supabase/supabase_providers.dart';
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
    remote: ProfileRemoteDataSource(ref.watch(supabaseClientServiceProvider)),
    local: ProfileLocalDataSource(prefs),
    allowOfflineFallback: !config.isProduction,
  );
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<UserProfile?>>((ref) {
      final identity = ref.watch(authenticatedUserIdProvider);
      final mirror = ref.watch(authControllerProvider).valueOrNull;
      final session = identity == null
          ? null
          : mirror?.userId == identity
          ? mirror
          : UserSession(userId: identity, authenticated: true);
      return ProfileController(
        ref.watch(profileRepositoryProvider),
        session,
        isCurrent: () => ref.read(authenticatedUserIdProvider) == identity,
      );
    });

class ProfileController extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileController(
    this._repository,
    this._session, {
    bool Function()? isCurrent,
  }) : _isCurrent = isCurrent ?? (() => true),
       super(const AsyncValue.loading()) {
    load();
  }

  final ProfileRepository _repository;
  final UserSession? _session;
  final bool Function() _isCurrent;
  bool get _active => mounted && _isCurrent();

  Future<void> load() async {
    if (!_active) return;
    final userId = _session?.userId;
    state = const AsyncValue.loading();
    if (userId == null || userId.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      var profile = await _repository.getProfile(userId);
      if (profile != null && profile.id != userId) {
        throw StateError("Profile owner mismatch");
      }
      final session = _session;
      if (profile == null && session != null) {
        final fullName = session.fullName;
        final parts = (fullName ?? '')
            .split(' ')
            .where((s) => s.isNotEmpty)
            .toList();
        profile = UserProfile(
          id: userId,
          firstName: parts.isNotEmpty ? parts.first : null,
          lastName: parts.length > 1 ? parts.sublist(1).join(' ') : null,
          email: session.email,
          phone: session.phone,
        );
      }
      if (!_active) return;
      state = AsyncValue.data(profile);
    } catch (e, st) {
      if (!_active) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(UserProfile profile) async {
    if (!_active || profile.id != _session?.userId) {
      throw StateError("Private session changed");
    }
    final previous = state;
    state = const AsyncValue<UserProfile?>.loading().copyWithPrevious(previous);
    try {
      final saved = await _repository.updateProfile(profile);
      if (!_active) throw StateError("Private session changed");
      if (saved.id != _session?.userId) {
        throw StateError("Profile owner mismatch");
      }
      state = AsyncValue.data(saved);
    } catch (e, st) {
      if (!_active) throw StateError("Private session changed");
      state = AsyncValue<UserProfile?>.error(e, st).copyWithPrevious(previous);
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
