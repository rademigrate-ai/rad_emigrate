import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../domain/entities/application_status.dart';
import '../../domain/entities/visa_application.dart';

class ApplicationRemoteDataSource {
  ApplicationRemoteDataSource(Object backend) : _backend = backend;

  final Object _backend;

  Future<List<VisaApplication>> list({String? userId}) async {
    if (_backend is ApiClient) {
      final response = await (_backend).get<List<dynamic>>(
        '/applications',
        queryParameters: userId != null ? {'userId': userId} : null,
      );
      return (response.data ?? const <dynamic>[])
          .map((e) => VisaApplication.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    try {
      var query = _service.client.from('applications').select();
      if (userId != null) query = query.eq('user_id', userId);
      final rows = await query.order('updated_at', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw _toApiException(error);
    }
  }

  Future<VisaApplication> get(String id) async {
    if (_backend is ApiClient) {
      final response = await (_backend).get<Map<String, dynamic>>(
        '/applications/$id',
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          message: 'Application not found',
          code: 'not_found',
        );
      }
      return VisaApplication.fromJson(data);
    }
    try {
      final row = await _service.client
          .from('applications')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) {
        throw const ApiException(
          message: 'Application not found',
          code: 'not_found',
        );
      }
      return _fromRow(row);
    } catch (error) {
      throw _toApiException(error);
    }
  }

  Future<VisaApplication> create(VisaApplication application) async {
    if (_backend is ApiClient) {
      final response = await (_backend).post<Map<String, dynamic>>(
        '/applications',
        data: application.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          message: 'Empty create response',
          code: 'empty_response',
        );
      }
      return VisaApplication.fromJson(data);
    }
    try {
      final userId = application.userId ?? _service.client.auth.currentUser?.id;
      if (userId == null) {
        throw const ApiException(
          message: 'No authenticated user.',
          code: 'not_authenticated',
        );
      }
      final row = await _service.client
          .from('applications')
          .insert({
            'user_id': userId,
            'visa_type': application.programName,
            'destination': application.country,
            'status': _statusToDb(application.status),
          })
          .select()
          .single();
      return _fromRow(row);
    } catch (error) {
      throw _toApiException(error);
    }
  }

  Future<VisaApplication> update(VisaApplication application) async {
    if (_backend is ApiClient) {
      final response = await (_backend).put<Map<String, dynamic>>(
        '/applications/${application.id}',
        data: application.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const ApiException(
          message: 'Empty update response',
          code: 'empty_response',
        );
      }
      return VisaApplication.fromJson(data);
    }
    try {
      final row = await _service.client
          .from('applications')
          .update({
            'visa_type': application.programName,
            'destination': application.country,
            'status': _statusToDb(application.status),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', application.id)
          .select()
          .single();
      return _fromRow(row);
    } catch (error) {
      throw _toApiException(error);
    }
  }

  SupabaseClientService get _service => _backend as SupabaseClientService;

  VisaApplication _fromRow(Map<String, dynamic> row) => VisaApplication(
    id: row['id'] as String,
    userId: row['user_id'] as String?,
    title: row['visa_type'] as String? ?? 'Visa application',
    programName: row['visa_type'] as String? ?? '',
    country: row['destination'] as String? ?? '',
    status: _statusFromDb(row['status'] as String? ?? 'draft'),
    updatedAt:
        DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
        DateTime.now(),
    createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
  );

  String _statusToDb(ApplicationStatus status) => switch (status) {
    ApplicationStatus.draft => 'draft',
    ApplicationStatus.submitted => 'submitted',
    ApplicationStatus.reviewing => 'under_review',
    ApplicationStatus.documentsRequired => 'documents_required',
    ApplicationStatus.approved => 'approved',
    ApplicationStatus.rejected => 'rejected',
    ApplicationStatus.completed => 'completed',
  };

  ApplicationStatus _statusFromDb(String value) => switch (value) {
    'under_review' => ApplicationStatus.reviewing,
    'documents_required' => ApplicationStatus.documentsRequired,
    _ => ApplicationStatusX.fromString(value),
  };

  ApiException _toApiException(Object error) => error is ApiException
      ? error
      : ApiException(message: error.toString(), code: 'supabase_error');
}
