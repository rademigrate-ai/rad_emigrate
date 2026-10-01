import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Lightweight request/response logger. Disabled in production via [enabled].
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({this.enabled = true});

  final bool enabled;
  static const _logName = 'rad_emigrate.http';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      developer.log('→ ${options.method} ${options.uri}', name: _logName);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enabled) {
      developer.log(
        '← ${response.statusCode} ${response.requestOptions.uri}',
        name: _logName,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      developer.log(
        '✕ ${err.response?.statusCode} ${err.requestOptions.uri} ${err.type}',
        name: _logName,
        error: err.error,
      );
    }
    handler.next(err);
  }
}
