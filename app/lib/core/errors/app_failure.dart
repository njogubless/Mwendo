/// Every failure the UI can see. Repositories translate transport errors into
/// these; widgets never inspect Dio exceptions or HTTP status codes.
///
/// [userMessage] is calm, human copy safe to display. [code] is the backend's
/// stable machine code (see backend `apps/core/exceptions.py`) for branching.
sealed class AppFailure implements Exception {
  const AppFailure({required this.userMessage, this.code, this.requestId});

  final String userMessage;
  final String? code;

  /// Echoed by the API (`X-Request-ID`) — include in bug reports / logs.
  final String? requestId;

  @override
  String toString() => '$runtimeType(code: $code, requestId: $requestId, message: $userMessage)';
}

/// No connectivity or the server could not be reached.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.userMessage = "We couldn't reach Mwendo. Check your connection and try again."})
    : super(code: 'network');
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.userMessage = 'This is taking longer than usual. Please try again.'})
    : super(code: 'timeout');
}

/// Session missing or expired and could not be refreshed.
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({super.userMessage = 'Please sign in to continue.', super.code, super.requestId});
}

/// Input rejected. [fieldErrors] maps API field names to messages for inline display.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.userMessage,
    this.fieldErrors = const {},
    super.code = 'validation_error',
    super.requestId,
  });

  final Map<String, List<String>> fieldErrors;

  String? firstErrorFor(String field) {
    final errors = fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.first;
  }
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.userMessage = "We couldn't find that.", super.code, super.requestId});
}

/// A business rule prevented the change (HTTP 409), e.g. completing a cancelled step.
final class ConflictFailure extends AppFailure {
  const ConflictFailure({required super.userMessage, super.code, super.requestId});
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({
    super.userMessage = 'Too many attempts. Please wait a moment and try again.',
    super.code = 'throttled',
    super.requestId,
  });
}

final class ServerFailure extends AppFailure {
  const ServerFailure({
    super.userMessage = 'Something went wrong on our side. Please try again.',
    super.code,
    super.requestId,
  });
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.userMessage = 'Something unexpected happened. Please try again.', this.cause})
    : super(code: 'unknown');

  final Object? cause;
}
