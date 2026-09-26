import 'package:json_annotation/json_annotation.dart';

import '../domain/user.dart';

part 'user_dto.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class UserDto {
  const UserDto({
    required this.id,
    required this.email,
    required this.displayName,
    required this.timezone,
    required this.dayStartTime,
    required this.isOnboarded,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) => _$UserDtoFromJson(json);

  final String id;
  final String email;
  final String displayName;
  final String timezone;

  /// `HH:MM[:SS]`
  final String dayStartTime;
  final bool isOnboarded;

  Map<String, dynamic> toJson() => _$UserDtoToJson(this);

  User toDomain() => User(
    id: id,
    email: email,
    displayName: displayName,
    timezone: timezone,
    dayStartTime: parseTimeOfDay(dayStartTime),
    isOnboarded: isOnboarded,
  );
}

/// Parses the API's `HH:MM[:SS]` into a duration since midnight.
Duration parseTimeOfDay(String value) {
  final parts = value.split(':').map(int.parse).toList();
  return Duration(hours: parts[0], minutes: parts.length > 1 ? parts[1] : 0, seconds: parts.length > 2 ? parts[2] : 0);
}
