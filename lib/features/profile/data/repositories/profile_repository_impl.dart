import '../../../../core/network/api_exception.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_local_datasource.dart';
import '../datasources/profile_remote_datasource.dart';

/// Coordinates remote + local profile storage.
/// Offline-safe: falls back to local when remote is unavailable.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required this.remote,
    required this.local,
    this.allowOfflineFallback = true,
  });

  final ProfileRemoteDataSource remote;
  final ProfileLocalDataSource local;
  final bool allowOfflineFallback;

  @override
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final result = await remote.getProfile(userId);
      await local.write(result);
      return result;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      return local.read(userId);
    }
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      final updated = await remote.updateProfile(profile);
      await local.write(updated);
      return updated;
    } on ApiException {
      if (!allowOfflineFallback) rethrow;
      await local.write(profile);
      return profile;
    }
  }
}
