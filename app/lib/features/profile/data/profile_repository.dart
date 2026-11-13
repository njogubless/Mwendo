import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend.dart';
import '../../../core/firebase/firestore_scope.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/failure_mapper.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/user_dto.dart';
import '../../auth/domain/user.dart';
import '../domain/profile_repository.dart';
import 'firestore_profile_repository.dart';

export '../domain/profile_repository.dart';

/// Account settings over the Django REST API.
class HttpProfileRepository implements ProfileRepository {
  HttpProfileRepository(this._dio);

  final Dio _dio;

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw mapToFailure(e);
    }
  }

  @override
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

  @override
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

  @override
  Future<User> completeOnboarding() =>
      _run(() async => UserDto.fromJson((await _dio.post<Json>('/me/onboarding/complete/')).data!).toDomain());

  @override
  Future<void> changePassword({required String current, required String next}) =>
      _run(() => _dio.post<void>('/me/password/', data: {'current_password': current, 'new_password': next}));

  @override
  Future<void> deleteAccount(String password) => _run(() => _dio.delete<void>('/me/', data: {'password': password}));
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => switch (ref.watch(backendProvider)) {
    Backend.django => HttpProfileRepository(ref.watch(apiClientProvider)),
    Backend.firebase => FirestoreProfileRepository(ref.watch(firestoreScopeProvider)),
  },
);
