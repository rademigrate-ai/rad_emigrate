import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'network_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Centralized HTTP client. Features must not use Dio directly.
class ApiClient {
  ApiClient({
    required NetworkConfig config,
    required Future<String?> Function() tokenProvider,
    Dio? dio,
  }) : _config = config {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: config.baseUrl,
            connectTimeout: config.connectTimeout,
            receiveTimeout: config.receiveTimeout,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );
    _dio.interceptors.addAll([
      AuthInterceptor(tokenProvider),
      LoggingInterceptor(enabled: config.enableLogging),
    ]);
  }

  final NetworkConfig _config;
  late final Dio _dio;

  NetworkConfig get config => _config;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _run(() => _dio.get<T>(path, queryParameters: queryParameters, options: options));

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _run(() => _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options));

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _run(() => _dio.put<T>(path, data: data, options: options));

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _run(() => _dio.patch<T>(path, data: data, options: options));

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _run(() => _dio.delete<T>(path, data: data, options: options));

  Future<Response<T>> _run<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.timeout(e);
      case DioExceptionType.connectionError:
        return ApiException.network(e);
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final msg = _extractMessage(e.response?.data);
        return ApiException.fromStatusCode(status, msg);
      case DioExceptionType.cancel:
        return const ApiException(message: 'Request cancelled', code: 'cancelled');
      default:
        return ApiException.network(e);
    }
  }

  String? _extractMessage(Object? data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
