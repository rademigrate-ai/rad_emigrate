import '../../../../core/network/api_exception.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_local_datasource.dart';
import '../datasources/profile_remote_datasource.dart';

/// Coordinates remote + local profile storage.
/// Offline-safe: falls back to local when remote is unavailable.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required ProfileRemoteDataSource remote,
    required ProfileLocalDataSource local,
    this.allowOfflineFallback = true,
  })  : _remote = remote,
        _local = local;

  final ProfileRemoteDataSource _remote;
  final ProfileLocalDataSource _local;
  final bool allowOfflineFallback;

  @override
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final remote = await _remote.getProfile(userId);
      await _local.write(remote);
      return remote;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      return _local.read(userId);
    }
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      final updated = await _remote.updateProfile(profile);
      await _local.write(updated);
      return updated;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      await _local.write(profile);
      return profile;
    }
  }
}
