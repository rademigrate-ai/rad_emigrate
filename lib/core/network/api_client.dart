import 'package:dio/dio.dart';

class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  Future<Response<T>> get<T>(String path) => dio.get<T>(path);
}
