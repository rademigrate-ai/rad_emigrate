import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/user_profile.dart';

/// Remote profile API contract. Throws [ApiException] when backend is offline.
class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._client);

  final ApiClient _client;

  Future<UserProfile> getProfile(String userId) async {
    final response = await _client.get<Map<String, dynamic>>('/users/$userId/profile');
    final data = response.data;
    if (data == null) {
      throw const ApiException(message: 'Empty profile response', code: 'empty_response');
    }
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/users/${profile.id}/profile',
      data: profile.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const ApiException(message: 'Empty profile response', code: 'empty_response');
    }
    return UserProfile.fromJson(data);
  }
}
