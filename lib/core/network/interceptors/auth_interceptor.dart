import 'package:dio/dio.dart';

/// Injects Authorization header when a token provider is available.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenProvider);

  final Future<String?> Function() _tokenProvider;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _tokenProvider();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Token lookup failure must not block the request pipeline.
    }
    handler.next(options);
  }
}
