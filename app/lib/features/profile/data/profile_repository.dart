import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/failure_mapper.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/user_dto.dart';
import '../../auth/domain/user.dart';

/// Account settings and onboarding answers for the signed-in user.
class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw mapToFailure(e);
    }
  }

  Future<User> update({String? displayName, String? timezone, int? dayStartMinutes}) => _run(() async {
    final r = await _dio.patch<Json>(
      '/me/',
      data: {
        'display_name': ?displayName,
        'timezone': ?timezone,
        if (dayStartMinutes != null) 'day_start_time': formatClockForApi(dayStartMinutes),
      },
    );
    return UserDto.fromJson(r.data!).toDomain();
  });

  Future<void> savePreferences({required List<String> focusAreas, required String structure, int? wakeMinutes}) => _run(
    () => _dio.put<Json>(
      '/me/preferences/',
      data: {
        'focus_areas': focusAreas,
        'structure': structure,
        'wake_time': wakeMinutes == null ? null : formatClockForApi(wakeMinutes),
        'ideal_day': <String, dynamic>{},
      },
    ),
  );

  Future<User> completeOnboarding() =>
      _run(() async => UserDto.fromJson((await _dio.post<Json>('/me/onboarding/complete/')).data!).toDomain());

  Future<void> changePassword({required String current, required String next}) =>
      _run(() => _dio.post<void>('/me/password/', data: {'current_password': current, 'new_password': next}));

  Future<void> deleteAccount(String password) => _run(() => _dio.delete<void>('/me/', data: {'password': password}));
}

final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(apiClientProvider)));
