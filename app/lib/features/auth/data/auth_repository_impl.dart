import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/failure_mapper.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';
import 'user_dto.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required Dio client, required TokenStorage storage}) : _client = client, _storage = storage;

  final Dio _client;
  final TokenStorage _storage;

  static final _public = Options(extra: {AuthInterceptor.skipAuthKey: true});

  @override
  Future<User?> restoreSession() async {
    if (await _storage.read() == null) return null;
    try {
      final response = await _client.get<Map<String, dynamic>>('/me/');
      return UserDto.fromJson(response.data!).toDomain();
    } on DioException catch (e) {
      final failure = mapToFailure(e);
      // The interceptor already tried a refresh; a 401 here means the session is gone.
      if (e.response?.statusCode == 401) {
        await _storage.clear();
        return null;
      }
      throw failure;
    }
  }

  @override
  Future<User> signIn({required String email, required String password}) =>
      _authenticate('/auth/login/', {'email': email, 'password': password});

  @override
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required String timezone,
  }) => _authenticate('/auth/register/', {
    'email': email,
    'password': password,
    'display_name': displayName,
    'timezone': timezone,
  });

  Future<User> _authenticate(String path, Map<String, dynamic> body) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(path, data: body, options: _public);
      final data = response.data!;
      await _storage.write(AuthTokens(access: data['access'] as String, refresh: data['refresh'] as String));
      return UserDto.fromJson(data['user'] as Map<String, dynamic>).toDomain();
    } catch (e) {
      throw mapToFailure(e);
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _client.post<void>('/auth/password/reset/', data: {'email': email}, options: _public);
    } catch (e) {
      throw mapToFailure(e);
    }
  }

  @override
  Future<User> confirmPasswordReset({required String email, required String code, required String newPassword}) =>
      _authenticate('/auth/password/reset/confirm/', {'email': email, 'code': code, 'new_password': newPassword});

  @override
  Future<void> signOut() async {
    final tokens = await _storage.read();
    try {
      if (tokens != null) await _client.post<void>('/auth/logout/', data: {'refresh': tokens.refresh});
    } on DioException {
      // Signing out locally must never fail because the network did.
    } finally {
      await _storage.clear();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(client: ref.watch(apiClientProvider), storage: ref.watch(tokenStorageProvider)),
);
