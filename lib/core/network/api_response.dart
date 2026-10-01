/// Generic API envelope used by remote datasources.
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
  });

  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;

  factory ApiResponse.ok(T data, {int? statusCode}) =>
      ApiResponse(success: true, data: data, statusCode: statusCode ?? 200);

  factory ApiResponse.fail(String message, {int? statusCode}) =>
      ApiResponse(success: false, message: message, statusCode: statusCode);
}
