/// Mapped network / API failures.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Object? cause;

  factory ApiException.network([Object? cause]) => ApiException(
        message: 'Network error. Check your connection and try again.',
        code: 'network_error',
        cause: cause,
      );

  factory ApiException.timeout([Object? cause]) => ApiException(
        message: 'Request timed out. Please try again.',
        code: 'timeout',
        cause: cause,
      );

  factory ApiException.unauthorized([String? message]) => ApiException(
        message: message ?? 'Session expired. Please sign in again.',
        statusCode: 401,
        code: 'unauthorized',
      );

  factory ApiException.forbidden([String? message]) => ApiException(
        message: message ?? 'You do not have permission for this action.',
        statusCode: 403,
        code: 'forbidden',
      );

  factory ApiException.notFound([String? message]) => ApiException(
        message: message ?? 'Resource not found.',
        statusCode: 404,
        code: 'not_found',
      );

  factory ApiException.server([String? message, int? statusCode]) => ApiException(
        message: message ?? 'Server error. Please try again later.',
        statusCode: statusCode ?? 500,
        code: 'server_error',
      );

  factory ApiException.fromStatusCode(int statusCode, [String? bodyMessage]) {
    switch (statusCode) {
      case 401:
        return ApiException.unauthorized(bodyMessage);
      case 403:
        return ApiException.forbidden(bodyMessage);
      case 404:
        return ApiException.notFound(bodyMessage);
      default:
        if (statusCode >= 500) {
          return ApiException.server(bodyMessage, statusCode);
        }
        return ApiException(
          message: bodyMessage ?? 'Request failed ($statusCode).',
          statusCode: statusCode,
          code: 'http_$statusCode',
        );
    }
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
