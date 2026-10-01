import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/visa_application.dart';

class ApplicationRemoteDataSource {
  ApplicationRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<VisaApplication>> list({String? userId}) async {
    final response = await _client.get<List<dynamic>>(
      '/applications',
      queryParameters: userId != null ? {'userId': userId} : null,
    );
    final data = response.data;
    if (data == null) return [];
    return data
        .map((e) => VisaApplication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<VisaApplication> get(String id) async {
    final response = await _client.get<Map<String, dynamic>>('/applications/$id');
    final data = response.data;
    if (data == null) {
      throw const ApiException(message: 'Application not found', code: 'not_found');
    }
    return VisaApplication.fromJson(data);
  }

  Future<VisaApplication> create(VisaApplication application) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/applications',
      data: application.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const ApiException(message: 'Empty create response', code: 'empty_response');
    }
    return VisaApplication.fromJson(data);
  }

  Future<VisaApplication> update(VisaApplication application) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/applications/${application.id}',
      data: application.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const ApiException(message: 'Empty update response', code: 'empty_response');
    }
    return VisaApplication.fromJson(data);
  }
}
