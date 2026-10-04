import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../domain/entities/user_profile.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(Object backend) : _backend = backend;

  final Object _backend;

  Future<UserProfile> getProfile(String userId) async {
    if (_backend is ApiClient) {
      final response = await (_backend).get<Map<String, dynamic>>(
        '/users/$userId/profile',
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          message: 'Empty profile response',
          code: 'empty_response',
        );
      }
      return UserProfile.fromJson(data);
    }
    try {
      final row = await _service.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row != null) return _fromRow(row);
      final user = _service.client.auth.currentUser;
      final created = await _service.client
          .from('profiles')
          .upsert({'id': userId, 'email': user?.email, 'phone': user?.phone})
          .select()
          .single();
      return _fromRow(created);
    } catch (error) {
      throw _toApiException(error);
    }
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    if (_backend is ApiClient) {
      final response = await (_backend).put<Map<String, dynamic>>(
        '/users/${profile.id}/profile',
        data: profile.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          message: 'Empty profile response',
          code: 'empty_response',
        );
      }
      return UserProfile.fromJson(data);
    }
    try {
      final row = await _service.client
          .from('profiles')
          .upsert(_toRow(profile))
          .select()
          .single();
      return _fromRow(row);
    } catch (error) {
      throw _toApiException(error);
    }
  }

  SupabaseClientService get _service => _backend as SupabaseClientService;

  UserProfile _fromRow(Map<String, dynamic> row) => UserProfile(
    id: row['id'] as String,
    firstName: _firstName(row['full_name'] as String?),
    lastName: _lastName(row['full_name'] as String?),
    email: row['email'] as String?,
    phone: row['phone'] as String?,
    nationality: row['country'] as String?,
    createdAt: _date(row['created_at']),
  );

  Map<String, dynamic> _toRow(UserProfile profile) => {
    'id': profile.id,
    'full_name': profile.fullName,
    'email': profile.email,
    'phone': profile.phone,
    'country': profile.nationality,
    'updated_at': DateTime.now().toIso8601String(),
  };

  String? _firstName(String? fullName) {
    final value = fullName?.trim();
    if (value == null || value.isEmpty) return null;
    return value.split(RegExp(r'\s+')).first;
  }

  String? _lastName(String? fullName) {
    final parts = fullName?.trim().split(RegExp(r'\s+')) ?? const <String>[];
    return parts.length > 1 ? parts.sublist(1).join(' ') : null;
  }

  DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  ApiException _toApiException(Object error) => error is ApiException
      ? error
      : ApiException(
          message: 'Unexpected Supabase error.',
          code: 'supabase_error',
          cause: error,
        );
}
