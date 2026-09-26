import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo/core/errors/app_failure.dart';
import 'package:mwendo/core/network/failure_mapper.dart';

DioException _response(int status, Object? data) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(requestOptions: options, statusCode: status, data: data),
  );
}

Map<String, dynamic> _envelope(String code, String message, [Map<String, dynamic> details = const {}]) => {
  'error': {'code': code, 'message': message, 'details': details, 'request_id': 'abc'},
};

void main() {
  test('validation envelope becomes ValidationFailure with field errors', () {
    final failure = mapToFailure(
      _response(
        400,
        _envelope('validation_error', 'Some details need another look.', {
          'email': ['An account with this email already exists.'],
        }),
      ),
    );

    expect(failure, isA<ValidationFailure>());
    final validation = failure as ValidationFailure;
    expect(validation.firstErrorFor('email'), 'An account with this email already exists.');
    expect(validation.requestId, 'abc');
  });

  test('409 keeps the server code and calm message', () {
    final failure = mapToFailure(_response(409, _envelope('already_completed', 'Already done.')));

    expect(failure, isA<ConflictFailure>());
    expect(failure.code, 'already_completed');
    expect(failure.userMessage, 'Already done.');
  });

  test('status codes map to typed failures', () {
    expect(mapToFailure(_response(401, null)), isA<UnauthorizedFailure>());
    expect(mapToFailure(_response(404, null)), isA<NotFoundFailure>());
    expect(mapToFailure(_response(429, null)), isA<RateLimitedFailure>());
    expect(mapToFailure(_response(500, '<html>')), isA<ServerFailure>());
  });

  test('transport problems map to network and timeout failures', () {
    final options = RequestOptions(path: '/x');
    expect(
      mapToFailure(DioException(requestOptions: options, type: DioExceptionType.connectionError)),
      isA<NetworkFailure>(),
    );
    expect(
      mapToFailure(DioException(requestOptions: options, type: DioExceptionType.receiveTimeout)),
      isA<TimeoutFailure>(),
    );
  });

  test('an AppFailure carried inside a DioException is unwrapped', () {
    final failure = mapToFailure(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const UnauthorizedFailure(),
      ),
    );

    expect(failure, isA<UnauthorizedFailure>());
  });

  test('non-network errors become UnknownFailure', () {
    expect(mapToFailure(StateError('boom')), isA<UnknownFailure>());
  });
}
