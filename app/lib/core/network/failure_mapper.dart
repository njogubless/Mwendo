import 'package:dio/dio.dart';

import '../errors/app_failure.dart';

/// Converts any error thrown by the HTTP layer into an [AppFailure].
///
/// Understands the backend envelope:
/// `{"error": {"code", "message", "details", "request_id"}}`.
AppFailure mapToFailure(Object error) {
  if (error is AppFailure) return error;
  if (error is! DioException) return UnknownFailure(cause: error);

  if (error.error is AppFailure) return error.error! as AppFailure;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return UnknownFailure(cause: error);
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  final response = error.response;
  if (response == null) return const NetworkFailure();

  final envelope = _envelope(response.data);
  final code = envelope?['code'] as String?;
  final message = envelope?['message'] as String?;
  final requestId = (envelope?['request_id'] as String?) ?? response.headers.value('x-request-id');

  return switch (response.statusCode ?? 0) {
    400 || 422 => ValidationFailure(
      userMessage: message ?? 'Some details need another look.',
      fieldErrors: _fieldErrors(envelope?['details']),
      code: code ?? 'validation_error',
      requestId: requestId,
    ),
    401 => UnauthorizedFailure(userMessage: message ?? 'Please sign in to continue.', code: code, requestId: requestId),
    403 => ConflictFailure(userMessage: message ?? "You don't have access to this.", code: code, requestId: requestId),
    404 => NotFoundFailure(code: code, requestId: requestId),
    409 => ConflictFailure(
      userMessage: message ?? "That change can't be made right now.",
      code: code,
      requestId: requestId,
    ),
    429 => RateLimitedFailure(requestId: requestId),
    _ => ServerFailure(code: code, requestId: requestId),
  };
}

Map<String, dynamic>? _envelope(Object? data) {
  if (data is Map<String, dynamic>) {
    final error = data['error'];
    if (error is Map<String, dynamic>) return error;
  }
  return null;
}

Map<String, List<String>> _fieldErrors(Object? details) {
  if (details is! Map<String, dynamic>) return const {};
  final result = <String, List<String>>{};
  details.forEach((field, value) {
    if (value is List) {
      result[field] = value.map((e) => e.toString()).toList();
    } else if (value != null) {
      result[field] = [value.toString()];
    }
  });
  return result;
}
