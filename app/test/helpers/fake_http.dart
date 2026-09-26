import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef Responder = Future<ResponseBody> Function(RequestOptions options);

/// Scriptable [HttpClientAdapter]: records requests, answers via [responder].
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.responder);

  Responder responder;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object? body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Map<String, dynamic> errorEnvelope(String code, String message, {Map<String, dynamic>? details}) => {
  'error': {'code': code, 'message': message, 'details': details ?? {}, 'request_id': 'req-1'},
};

Map<String, dynamic> userJson({bool onboarded = false}) => {
  'id': '6a1f0b8e-0000-4000-8000-000000000001',
  'email': 'zawadi@example.com',
  'display_name': 'Zawadi',
  'timezone': 'Africa/Nairobi',
  'day_start_time': '04:00:00',
  'is_onboarded': onboarded,
  'date_joined': '2026-09-26T07:00:00Z',
};
