/// Keeps the API's error details so forms can distinguish account and nickname
/// conflicts instead of reducing every rejection to the same message.
class ApiException implements Exception {
  final int? statusCode;
  final Object? code;
  final String message;
  final Object? detail;

  const ApiException({
    this.statusCode,
    this.code,
    required this.message,
    this.detail,
  });

  factory ApiException.fromResponse(
    int? statusCode,
    Map<String, dynamic> data,
  ) {
    return ApiException(
      statusCode: statusCode,
      code: data['error'] ?? data['code'],
      message: data['message']?.toString() ?? '请求失败',
      detail: data['detail'],
    );
  }

  @override
  String toString() {
    final description = detail?.toString();
    return description == null || description.isEmpty || description == ':('
        ? message
        : '$message: $description';
  }
}
