import 'package:dio/dio.dart';

/// Lightweight request/response logger. Disabled in production via [enabled].
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({this.enabled = true});

  final bool enabled;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      // Structured log boundary — no PII logging of bodies in production builds.
      assert(() {
        // ignore: avoid_print
        print('[HTTP] → ${options.method} ${options.uri}');
        return true;
      }());
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enabled) {
      assert(() {
        // ignore: avoid_print
        print('[HTTP] ← ${response.statusCode} ${response.requestOptions.uri}');
        return true;
      }());
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      assert(() {
        // ignore: avoid_print
        print(
          '[HTTP] ✕ ${err.response?.statusCode} ${err.requestOptions.uri} ${err.type}',
        );
        return true;
      }());
    }
    handler.next(err);
  }
}
