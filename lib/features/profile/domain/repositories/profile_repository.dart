import '../entities/user_profile.dart';

/// Profile repository contract. No live API required in PROJECT 02.
abstract class ProfileRepository {
  Future<UserProfile?> getProfile(String userId);
  Future<UserProfile> updateProfile(UserProfile profile);
}
